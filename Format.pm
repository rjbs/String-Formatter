package String::Format;

# ----------------------------------------------------------------------
# $Id: Format.pm,v 1.2 2003/03/06 19:12:04 dlc Exp $
# ----------------------------------------------------------------------
#  Copyright (C) 2002 darren chamberlain <darren@cpan.org>
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License as
#  published by the Free Software Foundation; version 2.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
#  USA
# -------------------------------------------------------------------

use strict;
use vars qw($VERSION @EXPORT $MARKER);
use Exporter;
use base qw(Exporter);

use Carp qw(carp);

$VERSION = 1.14;
@EXPORT  = qw(stringf);
$MARKER  = '%' unless defined $MARKER;

# ----------------------------------------------------------------------
# fmt($marker, $string);
#
# fmt takes a marker and a format string and returns a 2-element list,
# consisting of a sprintf format string and a reference to an array
# of arrays.  This AoA contains sequences, one per format character in
# the original string; each contains two elements: the actual format
# character (for lookups into the hash containing corresponding
# values) and the contents of any '{'...'}' stuff (which, if defined,
# will be passed to the sub reference contained in the hash, if it is
# a sub reference, which is usually will not be).
#
# It is intenteded to be invoked only by the stringf function.
#
# For example, the following invocation:
#
#   fmt("%", "Hello, %w!");
#
# Returns:
#
#   ("Hello, %s!", [ [ 'w', undef ], ])
#
# But a more complex invocation:
#
#   fmt("%", "My %-10.10{foo}a is on fire");
#
# Returns:
#
#   ("My %-10.10s is on fire", [ [ 'a', 'foo' ] ]);
#
# More examples:
#
#   fmt("#", "#a, #b, and #c");
#   ("%s, %s, and %s", [ [ 'a' => undef ], [ 'b' => undef ], [ 'c' => undef ] ]);
#
#   fmt("%", "%{%Y/%m/%d}d");
#   ("%s", [ [ 'd' => '%Y/%m/%d' ] ]);
#
# Clear as mud?
# ----------------------------------------------------------------------
sub fmt {
    my ($marker, $fmt) = @_;
    my @ret;

    $fmt =~ s/([^$marker]*)              # leading text                      $1
               (?:
                ($marker)                 # marker                            $2
                ([-])?                    # (optional) alignment              $3
                ([ 0])?                   # (optional) padder                 $4
                (\d*)?                    # (optional) minimum field width    $5
                (?:\.(\d*))?              # (optional) maximum field width    $6
                (?:\{([^$marker]*?)\})?   # (optional) stuff inside           $7
                (\S)                      # actual format character           $8
               )?
            /
        my ($m, $f);
        warn join "\n",
            "\$1 => '$1'",
            "\$2 => '$2'",
            "\$3 => '$3'",
            "\$4 => '$4'",
            "\$5 => '$5'",
            "\$6 => '$6'",
            "\$7 => '$7'",
            "\$8 => '$8'",
            "",
            "";

        if (length "$1") {
            if ($8 eq $marker) {
                $m = $marker eq '%' ? "$1%%" : "$1$marker";
            }

            $f = join '' => 
                (defined $3 ?  "$3" : ''),  # alignment  
                (defined $4 ?  "$4" : ''),  # padding
                (defined $5 ?  "$5" : ''),  # min width
                (defined $6 ?  "$6" : ''),  # max width
                's';

            push @ret, [ "$8", "$7" ]
                if length "$8";

            "$1%$m$f"
        } else {
            ""
        }
    /gex;

    return ($fmt, \@ret);
}

sub stringf {
    my $fmt = shift || return;
    my $hash = ref $_[0] eq 'HASH' ? shift : { @_ };
    my $marker = delete $hash->{'marker'} || $MARKER;
    my ($sfmt, $arr) = fmt($marker, $fmt);

    sprintf $sfmt, map { defined $hash->{$_->[0]}
                         ? ref($hash->{$_->[0]}) eq 'CODE'
                           ? $hash->{$_->[0]}->($_->[1])
                           : $hash->{$_->[0]}
                         : "$marker$_->[0]"
                        } @$arr;
}


sub stringfactory {
    shift;  # It's a class method, but we don't actually want the class
    my $args = UNIVERSAL::isa($_[0], "HASH") ? shift : { @_ };
    return sub { stringf($_[0], $args) };
}

1;
__END__

=head1 NAME

String::Format - sprintf-like string formatting capabilities with
arbitrary format definitions

=head1 ABSTRACT

Process sprintf-style formats with arbitrary format definitions

=head1 SYNOPSIS

  use String::Format;

  my $fmt = "I like %a, %b, and %g, but not %m or %w.";
  my %fruit = (
        'a' => "apples",
        'b' => "bannanas",
        'g' => "grapefruits",
        'm' => "melons",
        'w' => "watermelons",
  );

  print stringf $fmt, \%fruit;
  
  # prints:
  # I like apples, bannanas, and grapefruits, but not melons or watermelons.

=head1 DESCRIPTION

String::Format lets you define arbitrary sprintf-like format sequences
to be expanded.  This module would be most useful in configuration
files and reporting tools, where the results of a query need to be
formatted in a particular way.  It was inspired by mutt's index_format
and related directives (see
<URL:http://www.mutt.org/doc/manual/manual-6.html#index_format>).

=head1 FUNCTIONS

=head2 stringf

String::Format exports a single function called stringf.  stringf
takes two arguments:  a format string (see FORMAT STRINGS, below) and
a reference to a hash of name => value pairs.  These name => value
pairs are what will be expanded in the format string.

=head1 FORMAT STRINGS

Format strings must match the following regular expression:

  qr/
     ($MARKER       # leading '%'
      (-)?          # left-align, rather than right
      (\d*)?        # (optional) minimum field width
      (?:\.(\d*))?  # (optional) maximum field width
      ({.*?})?      # (optional) stuff inside
      (\S)          # actual format character
     )/x;

If the escape character specified does not exist in %args, then the
original string is used, including $MARKER.  The alignment, minimum
width, and maximum width options function identically to how they are
defined in sprintf(3) (any variation is a bug, and should be
reported; see L<"REPORTING BUGS">).

Note that Perl's sprintf definition is a little more liberal than the
above regex; the deviations were intentional, and all deal with
numeric formatting (the #, 0, and + leaders were specifically left
out).

The value attached to the key can be a scalar value or a subroutine
reference; if it is a subroutine reference, then anything between the
'{' and '}' ($5 in the above regex) will be passed as $_[0] to the
subroutine reference.  This allows for entries such as this:

  %args = (
      d => sub { POSIX::strftime($_[0], localtime) }, 
  );

Which can be invoked with this format string:

  "It is %{%H:%M}d right now, on %{%A, %B %e}d."

And result in (for example):

  It is 07:29 right now, on Thursday, January 16.

Note that since the string is passed unmolested to the subroutine
reference, and strftime would Do The Right Thing with this data, the
above format string could also be written as:

  "It is %{%H:%M right now, on %A, %B %e}d."

By default, the formats 'n', 't', and '%' are defined to be a newline,
tab, and '%', respectively, if they are not already defined in the
hashref of arguments that gets passed it.  So we can add carriage
returns simply:

  "It is %{%M:%S right now, on %A, %B %e}d.%n"

Because of how the string is parsed, the normal "\n" and "\t" are
turned into two characters each, and are not treated as a newline and
tab.  This is a bug.

=head1 CHANGING THE FORMAT MARKER

The package global $MARKER defines the special character that
C<stringf> uses to determine whether a format is found or not; by
default, $MARKER is set to '%', but it can be set to anything else.

=head1 FACTORY METHOD

String::Format also supports a class method, named B<stringfactory>,
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
  my $index_format = String::Format->stringfactory(\%formats);

  print $index_format->($format1);
  print $index_format->($format2);

This subroutine reference can be assigned to a local symbol table
entry, and called normally, of course:

  *reformat = String::Format->stringfactory(\%formats);

  my $reformed = reformat($format_string);

Formatting methods can be added to packages using symbol table trickery:

  package My::Config;
  use String::Format ();

  my %generic_formats = (
      ....
  );

  my %index_format = (
      %generic_formats,
      ...
  );

  my %status_format = (
      %generic_formats,
      ...
  );

  *index_format = String::Format->stringfactory(\%index_formats);
  *status_format = String::Format->stringfactory(\%status_format)

These can then be used:

  use My::Config;

  my $cfg = My::Config->new();

  print $cfg->index_format("Hello, %w");

=head1 REPORTING BUGS

Please report all bugs the the String::Format RT queue at
E<lt>https://rt.cpan.org/E<gt>.

=head1 AUTHOR

darren chamberlain E<lt>darren@cpan.orgE<gt>
