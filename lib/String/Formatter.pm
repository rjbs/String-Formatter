use strict;
use warnings;
package String::Formatter;
# ABSTRACT: build sprintf-like functions of your own

our $VERSION = '1.16';

=head1 DESCRIPTION

String::Formatter lets you define arbitrary printf-like format sequences to be
expanded.  This module would be most useful in configuration files and
reporting tools, where the results of a query need to be formatted in a
particular way.  String::Stringf is derived from String::Format, which was
inspired by mutt's index_format and related directives (see
<URL:http://www.mutt.org/doc/manual/manual-6.html#index_format>).

=cut

require 5.006;

use Params::Util ();
# use Sub::Exporter -setup => {
#   exports => [ stringf => \'_build_stringf' ],
#   groups  => [ default => [qw(stringf)] ],
# };

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

my $regex = qr/
 (%                # leading '%'
  (-)?             # left-align, rather than right
  ([0-9]+)?        # (optional) minimum field width
  (?:\.([0-9]*))?  # (optional) maximum field width
  (?:{(.*?)})?     # (optional) stuff inside
  (\S)             # actual format character
 )
/x;

sub codes { $_[0]->{codes} }

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

sub return_input {
  return $_[1];
}

sub require_named_input {
  my ($self, $args) = @_;

  Carp::croak("routine must be called with exactly one hashref arg")
    if @$args != 1 or ! Params::Util::_HASHLIKE($args->[0]);

  return $args->[0];
}

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

sub positional_replace {
  my ($self, $hunks, $args) = @_;

  my $code = $self->codes;
  my $nth = 0;

  for my $i (grep { ref $hunks->[$_] } 0 .. $#$hunks) {
    my $hunk = $hunks->[ $i ];
    my $conv = $code->{ $hunk->{formchar} };

    Carp::croak("Unknown conversion in stringf-generated routine: $hunk->{formchar}") unless defined $conv;

    if (ref $conv) {
      local $_ = $args->[ $nth ];
      $hunks->[ $i ]->{replacement} = $conv->($self, $_, $hunk->{passme});
      $nth++;
    } else {
      $hunks->[ $i ]->{replacement} = $conv;
    }
  }
}

sub named_replace {
  my ($self, $hunks, $input) = @_;

  my $code = $self->codes;
  my $nth = 0;

  for my $i (grep { ref $hunks->[$_] } 0 .. $#$hunks) {
    my $hunk = $hunks->[ $i ];
    my $conv = $code->{ $hunk->{formchar} };

    Carp::croak("Unknown conversion in stringf-generated routine: $hunk->{formchar}") unless defined $conv;

    if (ref $conv) {
      Carp::croak("no input for requested variable $hunk->{passme}")
        unless exists $input->{ $hunk->{passme} };

      local $_ = $input->{ $hunk->{passme} };
      $hunks->[ $i ]->{replacement} = $conv->($self, $_, $hunk->{passme});
    } else {
      $hunks->[ $i ]->{replacement} = $conv;
    }
  }
}

1;
__END__

=head1 FUNCTIONS

=head2 stringf

String::Stringf can export a single function called stringf.  stringf
takes two arguments:  a format string (see FORMAT STRINGS, below) and
a reference to a hash of name => value pairs.  These name => value
pairs are what will be expanded in the format string.

=head1 FORMAT STRINGS

Format strings are strings with embedded format markers.  If you've used C or
Perl's C<sprintf>, you already understand.  If you haven't, you should read
about how C<sprintf> works.

Format markers are generally in the form:

  %    - a percent sign to begin the format
  ...  - (optional) various modifiers to the format like "-5" or "#" or "2$"
  {..} - (optional) a string inside braces
  s    - a short string (usually one character) identifying the conversion

Not all formatters found in Perl's C<sprintf> are yet supported.  Currently the
only format modifers must match:

    (-)?          # left-align, rather than right
    (\d*)?        # (optional) minimum field width
    (?:\.(\d*))?  # (optional) maximum field width

If a format string has an unknown conversion, an exception will be raised.

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

=head1 DERIVATION

String::Stringf is based on String::Format, written by Darren Chamberlain.  For
a history of the code, check the project's source code repository.  All bugs
should be reported to Ricardo Signes and String::Stringf.

=end :postlude
