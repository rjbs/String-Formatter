use strict;
use warnings;
package String::Stringf;
# ABSTRACT: build sprintf-like functions of your own

our $VERSION = '1.16';

=head1 SYNOPSIS

  use String::Stringf;

  my %fruit = (
    a => "apples",
    b => "bannanas",
    g => "grapefruits",
    m => "melons",
    w => "watermelons",
  );

  my $format = "I like %a, %b, and %g, but not %m or %w.";

  print stringf($format, %fruit);
  
...prints:

  I like apples, bannanas, and grapefruits, but not melons or watermelons.

=head1 DESCRIPTION

String::Stringf lets you define arbitrary printf-like format sequences to be
expanded.  This module would be most useful in configuration files and
reporting tools, where the results of a query need to be formatted in a
particular way.  String::Stringf is derived from String::Format, which was
inspired by mutt's index_format and related directives (see
<URL:http://www.mutt.org/doc/manual/manual-6.html#index_format>).

=cut

require 5.006;

use Params::Util ();
use Sub::Exporter -setup => {
  exports => [ stringf => \'_build_stringf' ],
  groups  => [ default => [qw(stringf)] ],
};

sub _replace {
  my (
    $letter, $orig,     $alignment, $min_width, $max_width,
    $passme, $formchar, $args,      $i_ref
  ) = @_;

  # For unknown escapes, return the orignial
  unless (defined $letter->{$formchar}) {
    $$i_ref--;
    return $orig;
  }

  $alignment = '+' unless defined $alignment;

  my $replacement = $letter->{$formchar};
  if (ref $replacement eq 'CODE') {

    # $passme gets passed to subrefs.
    $passme ||= "";
    $passme =~ s/\A{//g;
    $passme =~ s/}\z//g;
    $replacement = $replacement->($passme, $$i_ref, $args);
  }

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
  if ($alignment eq '-') {

    # left align; pad in front
    return $replacement . " " x ($min_width - $replength);
  }

  # right align, pad at end
  return " " x ($min_width - $replength) . $replacement;
}

my $regex = qr/
 (%             # leading '%'
  (-)?          # left-align, rather than right
  (\d*)?        # (optional) minimum field width
  (?:\.(\d*))?  # (optional) maximum field width
  ({.*?})?      # (optional) stuff inside
  (\S)          # actual format character
 )
/x;

sub stringf {
  my $format = shift || return;
  my $args = Params::Util::_HASHLIKE($_[0]) ? shift : {@_};

  _build_stringf(__PACKAGE__, 'stringf', { formats => $args, },)->($format);
}

sub stringfactory {
  my $class = shift;
  my $args = Params::Util::_HASHLIKE($_[0]) ? shift : {@_};
  return $class->_build_stringf(stringf => { formats => $args });
}

sub _build_stringf {
  my ($self, $name, $arg) = @_;
  return $self->can('stringf') unless %$arg;
  Carp::confess('no formats given') unless my $format = $arg->{formats};

  $format->{'n'} = "\n" unless exists $format->{'n'};
  $format->{'t'} = "\t" unless exists $format->{'t'};
  $format->{'%'} = "%"  unless exists $format->{'%'};

  return sub {
    # This is the previous behavior, but I think we should die instead,
    # like sprintf. -- rjbs, 2009-05-15
    Carp::croak("not enough arguments for stringf-based format") unless @_;

    return unless defined (my $string = shift);
    my $i = -1;

    $string =~ s/$regex/
      $i++;
      _replace($format, $1, $2, $3, $4, $5, $6, \@_, \$i);
    /ge;

    return $string;
  };
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

=head1 FACTORY METHOD

String::Stringf also supports a class method, named B<stringfactory>,
which will return reference to a "primed" subroutine.  stringfatory
should be passed a reference to a hash of value; the returned
subroutine will use these values as the %args hash.

  my $self = Some::Groovy::Package->new($$, $<, $^T);
  my %formats = (
        'i' => sub { $self->id      },
        'd' => sub { $self->date    },
        's' => sub { $self->subject },
        'b' => sub { $self->body    },
  );
  my $index_format = String::Stringf->stringfactory(\%formats);

  print $index_format->($format1);
  print $index_format->($format2);

This subroutine reference can be assigned to a local symbol table
entry, and called normally, of course:

  *reformat = String::Stringf->stringfactory(\%formats);

  my $reformed = reformat($format_string);

=head1 LICENSE

C<String::Stringf> is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License as
published by the Free Software Foundation; version 2.


=head1 AUTHOR

darren chamberlain <darren@cpan.org>
