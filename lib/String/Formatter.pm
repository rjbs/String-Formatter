use strict;
use warnings;
package String::Formatter;
# ABSTRACT: build sprintf-like functions of your own

=begin :prelude

=head1 WARNING

This module is brand new (as of today, 2009-11-16) and parts of its interface
may change substantially before this warning goes away!

=end :prelude

=head1 SYNOPSIS

  use String::Formatter stringf => {
    -as   => 'str_rf',
    codes => {
      f => sub { $_ },
      b => sub { scalar reverse $_ },
      o => 'Okay?',
    },
  };

  print str_rf('This is %10f and this is %-15b, %o', 'forward', 'backward');

...prints...

  This is    forward and this is drawkcab       , okay?

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

There's also a C<named_stringf> export, which behaves just like the C<stringf>
export, but defaults to the C<named_replace> and C<require_named_input>
arguments, and a C<method_stringf> export, which defaults C<method_replace> and
C<require_single_input>.  For more on these, keep reading, and check out the
cookbook.

L<String::Formatter::Cookbook> provides a number of recipes for ways to put
String::Formatter to use.

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
  exports => {
    stringf => sub {
      my ($class, $name, $arg, $col) = @_;
      my $formatter = $class->new($arg);
      return sub { $formatter->format(@_) };
    },
    method_stringf => sub {
      my ($class, $name, $arg, $col) = @_;
      my $formatter = $class->new({
        input_processor => 'require_single_input',
        string_replacer => 'method_replace',
        %$arg,
      });
      return sub { $formatter->format(@_) };
    },
    named_stringf => sub {
      my ($class, $name, $arg, $col) = @_;
      my $formatter = $class->new({
        input_processor => 'require_named_input',
        string_replacer => 'named_replace',
        %$arg,
      });
      return sub { $formatter->format(@_) };
    },
  },
};

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

=method new

=for Pod::Coverage
  codes 
  default_format_hunker
  default_input_processor
  default_string_replacer
  default_hunk_formatter

  my $formatter = String::Formatter->new({
    codes => { ... },
    format_hunker   => ...,
    input_processor => ...,
    string_replacer => ...,
    hunk_formatter  => ...,
  });

This returns a new formatter.  The C<codes> argument contains the formatting
codes for the formatter in the form:

  codes => {
    s => 'fixed string',
    S => 'different string',
    c => sub { ... },
  }

Code values (or "conversions") should either be strings or coderefs.  This
hashref can be accessed later with the C<codes> method.

The other four arguments change how the formatting occurs.  Formatting happens
in five phases:

=for wikidoc
0 format_hunker - format string is broken down into fixed and %-code hunks
0 input_processor - the other inputs are validated and processed
0 string_replacer - replacement strings are generated by using conversions
0 hunk_formatter - replacement strings in hunks are formatted
0 all hunks, now strings, are recombined; this phase is just {join}

The defaults are found by calling C<default_WHATEVER> for each helper that
isn't given.  Values must be either strings (which are interpreted as method
names) or coderefs.  The semantics for each method are descibed in the methods' sections, below.

=cut

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

=method format

  my $result = $formatter->format( $format_string, @input );

  print $formatter->format("My %h is full of %e.\n", 'hovercraft', 'eels');

This does the actual formatting, calling the methods described above, under
C<L</new>> and returning the result.

=cut

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

=method format_hunker

Format hunkers are passed strings and return arrayrefs containing strings (for
fixed content) and hashrefs (for formatting code sections).

The semantics of the hashrefs returned are not yet stable enough to be worth
documenting.

=method hunk_simply

This is the default format hunker.  It implements the format string semantics
L<described above|/FORMAT STRINGS>.

=cut

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

=method input_processor

The input processor is responsible for inspecting the post-format-string
arguments, validating them, and returning them in a possibly-transformed form.
The processor is passed an arrayref containing the arguments and should return
a scalar value to be used as the input going forward.

=method return_input

This input processor, the default, simply returns the input it was given with
no validation or transformation.

=cut

sub return_input {
  return $_[1];
}

=method require_named_input

This input processor will raise an exception unless there is exactly one
post-format-string argument to the format call, and unless that argument is a
hashref.  It will also replace the arrayref with the given hashref so
subsequent phases of the format can avoid lots of needless array dereferencing.

=cut

sub require_named_input {
  my ($self, $args) = @_;

  Carp::croak("routine must be called with exactly one hashref arg")
    if @$args != 1 or ! Params::Util::_HASHLIKE($args->[0]);

  return $args->[0];
}

=method require_single_input

This input processor will raise an exception if more than one input is given.
After input processing, the single element in the input will be used as the
input itself.

=cut

sub require_single_input {
  my ($self, $args) = @_;

  Carp::croak("routine must be called with exactly one argument after string")
    if @$args != 1;

  return $args->[0];
}

=method forbid_input

This input processor will raise an exception if any input is given.  In other
words, formatters with this input processor accept format strings and nothing
else.

=cut

sub forbid_input {
  my ($self, $args) = @_;

  Carp::croak("routine must be called with no arguments after format string")
    if @$args;

  return $args;
}

=method string_replacer

The string_replacer phase is responsible for adding a C<replacement> entry to
format code hunks.  This should be a string-value entry that will be formatted
and concatenated into the output string.  String replacers can also replace the
whole hunk with a string to avoid any subsequent formatting.

=method positional_replace

This replacer matches inputs to the hunk's position in the format string.  This
is the default replacer, used in the L<synopsis, above|/SYNOPSIS>, which should
make its behavior clear.  At present, fixed-string conversions B<do not> affect
the position of arg matched, meaning that given the following:

  my $formatter = String::Formatter->new({
    codes => {
      f => 'fixed string',
      s => sub { ... },
    }
  });

  $formatter->format("%s %f %s", 1, 2);

The subroutine is called twice, once for the input C<1> and once for the input
C<2>.  B<This behavior may change> after some more experimental use.

=method named_replace

This replacer should be used with the C<require_named_input> input processor.
It expects the input to be a hashref and it finds values to be interpolated by
looking in the hashref for the brace-enclosed name on each format code.  Here's
an example use:

  $formatter->format("This was the %{adj}s day in %{num}d weeks.", {
    adj => 'best',
    num => 6,
  });

=cut

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

=method method_replace

This string replacer method expects the input to be a single value on which
methods can be called.  If a value was given in braces to the format code, it
is passed as an argument.

=cut

sub method_replace {
  my ($self, $hunks, $input) = @_;

  my $heap = {};
  my $code = $self->codes;

  for my $i (grep { ref $hunks->[$_] } 0 .. $#$hunks) {
    my $hunk = $hunks->[ $i ];
    my $conv = $code->{ $hunk->{formchar} };

    Carp::croak("Unknown conversion in stringf: $hunk->{formchar}")
      unless defined $conv;

    if (ref $conv) {
      $hunks->[ $i ]->{replacement} = $input->$conv($hunk->{passme});
    } else {
      $hunks->[ $i ]->{replacement} = $input->$conv(
        defined $hunk->{passme} ? $hunk->{passme} : ()
      );
    }
  }
}

=method hunk_formatter

The hunk_formatter processes each the hashref hunks left after string
replacement and returns a string.  When it is called, it is passed a hunk
hashref and must return a string.

=method format_simply

This is the default hunk formatter.  It deals with minimum and maximum width
cues as well as left and right alignment.  Beyond that, it does no formatting
of the replacement string.

=cut

sub format_simply {
  my ($self, $hunk) = @_;

  my $replacement = $hunk->{replacement};
  my $replength   = length $replacement;

  my $alignment   = $hunk->{alignment} || '';
  my $min_width   = $hunk->{min_width} || 0;
  my $max_width   = $hunk->{max_width} || $replength;

  $min_width ||= $replength > $min_width ? $min_width : $replength;
  $max_width ||= $max_width > $replength ? $max_width : $replength;

  return sprintf "%$alignment${min_width}.${max_width}s", $replacement;
}

1;

=begin :postlude

=head1 HISTORY

String::Formatter is based on L<String::Format|String::Format>, written by
Darren Chamberlain.  For a history of the code, check the project's source code
repository.  All bugs should be reported to Ricardo Signes and
String::Formatter.  Very little of the original code remains.

=end :postlude
