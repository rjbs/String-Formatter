use strict;
use warnings;
package String::Formatter;
# ABSTRACT: build sprintf-like functions of your own

our $VERSION = '1.16';

=head1 SYNOPSIS

  use String::Formatter stringf => {
    -as   => 'str_rf',
    codes => {
      f => sub { $_ },
      b => sub { scalar reverse $_ },
    },
  };


  print str_rf('This is %10f and this is %-15b.', 'forward', 'backward');

...prints...

  This is    forward and this is drawkcab       .

=head1 DESCRIPTION

String::Formatter is a tool for building sprintf-like formatting routines.
It supports named or positional formatting, custom conversions, fixed string
interpolation, and simple width-matching out of the box.  It is easy to alter
its behavior to write new kinds of format string expanders.  For most cases, it
should be easy to build all sorts of formatters out of the options built into
String::Formatter.

Normally, String::Formatter will be used to import a sprintf-like routine
referred to as "C<stringf>", but which can be given any name you like.  This
routine acts like sprintf in that it takes a string and some inputs and returns
a new string:

  my $output = stringf "Some %a format %s for you to %u.\n", { ... };

This routine is actually a wrapper around a String::Formatter object created by
importing stringf.  In the following code, the entire hashref after "stringf"
is passed to String::Formatter's constructor (the C<new> method), save for the
C<-as> key and any other keys that start with a dash.

  use String::Formatter
    stringf => {
      -as => 'fmt_time',
      codes           => { ... },
      format_hunker   => ...,
      input_processor => ...,
    },
    stringf => {
      -as => 'fmt_date',
      codes           => { ... },
      string_replacer => ...,
      hunk_formatter  => ...,
    },
  ;

As you can see, this will generate two stringf routines, with different
behaviors, which are installed with different names.  Since the behavior of
these routines is based on the C<format> method of a String::Formatter object,
the rest of the documentation will describe the way the object behaves.

=head1 FORMAT STRINGS

Format strings are generally assumed to look like Perl's sprintf's format
strings:

  There's a bunch of normal strings and then %s format %1.4c with %% signs.

The exact semantics of the format codes are not totally settled yet -- and they
can be replaced on a per-formatter basis.  Right now, they're mostly a subset
of Perl's astonishingly large and complex system.  That subset looks like this:

  %    - a percent sign to begin the format
  ...  - (optional) various modifiers to the format like "-5" or "#" or "2$"
  {..} - (optional) a string inside braces
  s    - a short string (usually one character) identifying the conversion

Not all format modifiers found in Perl's C<sprintf> are yet supported.
Currently the only format modifers must match:

    (-)?          # left-align, rather than right
    (\d*)?        # (optional) minimum field width
    (?:\.(\d*))?  # (optional) maximum field width

Some additional format semantics may be added, but probably nothing exotic.
Even things like C<2$> and C<*> are probably not going to appear in
String::Formatter's default behavior.

=cut

require 5.006;

use Params::Util ();
use Sub::Exporter -setup => {
  exports => [ stringf => \'_build_stringf' ],
};

sub _build_stringf {
  my ($class, $name, $arg, $col) = @_;
  
  my $formatter = $class->new($arg);
  return sub { $formatter->format(@_) };
}

my %METHODS;
BEGIN {
  %METHODS = (
    format_hunker   => 'hunk_simply',
    input_processor => 'return_input',
    string_replacer => 'positional_replace',
    hunk_formatter  => 'format_simply',
  );
  
  no strict 'refs';
  for my $method (keys %METHODS) {
    *$method = sub { $_[0]->{ $method } };

    my $default = "default_$method";
    *$default = sub { $METHODS{ $method } };
  }
}

sub new {
  my ($class, $arg) = @_;

  my $self = bless { codes => $arg->{codes} } => $class;

  for (keys %METHODS) {
    $self->{ $_ } = $arg->{ $_ } || do {
      my $default_method = "default_$_";
      $class->$default_method;
    };

    $self->{$_} = $self->can($self->{$_}) unless ref $self->{$_};
  }

  my $codes = $self->codes;

  Carp::confess("you must not supply a % format") if defined $codes->{'%'};
  $codes->{'%'} = '%';

  return $self;
}

sub codes { $_[0]->{codes} }

sub format {
  my $self   = shift;
  my $format = shift;

  Carp::croak("not enough arguments for stringf-based format")
    unless defined $format;

  my $hunker = $self->format_hunker;
  my $hunks  = $self->$hunker($format);

  my $processor = $self->input_processor;
  my $input = $self->$processor([ @_ ]);

  my $replacer = $self->string_replacer;
  $self->$replacer($hunks, $input);

  my $formatter = $self->hunk_formatter;
  ref($_) and $_ = $self->$formatter($_) for @$hunks;

  my $string = join q{}, @$hunks;

  return $string;
}

my $regex = qr/
 (%                # leading '%'
  (-)?             # left-align, rather than right
  ([0-9]+)?        # (optional) minimum field width
  (?:\.([0-9]*))?  # (optional) maximum field width
  (?:{(.*?)})?     # (optional) stuff inside
  (\S)             # actual format character
 )
/x;

sub hunk_simply {
  my ($self, $string) = @_;

  my @to_fmt;
  my $pos = 0;

  while ($string =~ m{\G(.*?)$regex}g) {
    push @to_fmt, $1, {
      orig      => $2,
      alignment => $3,
      min_width => $4,
      max_width => $5,
      passme    => $6,
      formchar  => $7,
    };

    $pos = pos $string;
  }

  push @to_fmt, substr $string, $pos if $pos < length $string;

  return \@to_fmt;
}

sub return_input {
  return $_[1];
}

sub require_named_input {
  my ($self, $args) = @_;

  Carp::croak("routine must be called with exactly one hashref arg")
    if @$args != 1 or ! Params::Util::_HASHLIKE($args->[0]);

  return $args->[0];
}

sub __closure_replace {
  my ($closure) = @_;
  
  return sub {
    my ($self, $hunks, $input) = @_;

    my $heap = {};
    my $code = $self->codes;

    for my $i (grep { ref $hunks->[$_] } 0 .. $#$hunks) {
      my $hunk = $hunks->[ $i ];
      my $conv = $code->{ $hunk->{formchar} };

      Carp::croak("Unknown conversion in stringf: $hunk->{formchar}")
        unless defined $conv;

      if (ref $conv) {
        $hunks->[ $i ]->{replacement} = $self->$closure({
          conv => $conv,
          hunk => $hunk,
          heap => $heap,
          input => $input,
        });
      } else {
        $hunks->[ $i ]->{replacement} = $conv;
      }
    }
  };
}

BEGIN {
  *positional_replace = __closure_replace(sub {
    my ($self, $arg) = @_;
    local $_ = $arg->{input}->[ $arg->{heap}{nth}++ ];
    return $arg->{conv}->($self, $_, $arg->{hunk}{passme});
  });

  *named_replace = __closure_replace(sub {
    my ($self, $arg) = @_;
    local $_ = $arg->{input}->{ $arg->{hunk}{passme} };
    return $arg->{conv}->($self, $_, $arg->{hunk}{passme});
  });
}

sub format_simply {
  my ($self, $hunk) = @_;

  my $alignment   = $hunk->{alignment};
  my $min_width   = $hunk->{min_width};
  my $max_width   = $hunk->{max_width};
  my $replacement = $hunk->{replacement};

  my $replength = length $replacement;
  $min_width ||= $replength;
  $max_width ||= $replength;

  # length of replacement is between min and max
  if (($replength > $min_width) && ($replength < $max_width)) {
    return $replacement;
  }

  # length of replacement is longer than max; truncate
  if ($replength > $max_width) {
    return substr($replacement, 0, $max_width);
  }

  # length of replacement is less than min: pad
  # alignment can only be '-' or undef, so - is true -- rjbs, 2009-11-16
  return $alignment
       ? $replacement . " " x ($min_width - $replength)
       : " " x ($min_width - $replength) . $replacement;
}

1;
__END__

=head1 CONVERSIONS

C<stringf> routines must be provided with a set of conversions.  They're
provided as a hashref in which the keys are the conversion identifiers and the
values are either strings or coderefs.

If the values are strings then the string is the value that is used for the
conversion.  If it is a subroutine reference, the sub will be called once for
each time it appears in the format string, with the following arguments:

  $code->( ... );

This allows for entries such as this:

  %args = (
      d => sub { POSIX::strftime($_[0], localtime) }, 
  );

Which can be invoked with this format string:

  "It is %{%M:%S}d right now, on %{%A, %B %e}d."

And result in (for example):

  It is 17:45 right now, on Monday, February 4.

Note that since the string is passed unmolested to the subroutine
reference, and strftime would Do The Right Thing with this data, the
above format string could be written as:

  "It is %{%M:%S right now, on %A, %B %e}d."

By default, the formats 'n', 't', and '%' are defined to be a newline,
tab, and '%', respectively, if they are not already defined in the
hashref of arguments that gets passed it.  So we can add carriage
returns simply:

  "It is %{%M:%S right now, on %A, %B %e}d.%n"

Because of how the string is parsed, the normal "\n" and "\t" are
turned into two characters each, and are not treated as a newline and
tab.  This is a bug.

=begin :postlude

=head1 HISTORY

String::Formatter is based on String::Format, written by Darren Chamberlain.
For a history of the code, check the project's source code repository.  All
bugs should be reported to Ricardo Signes and String::Formatter.  Very little
of the original code remains.

=end :postlude
