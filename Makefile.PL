package String::Format;

use strict;
use ExtUtils::MakeMaker;

my @ppd;

if ($] >= 5.00503) {
  @ppd = (
    AUTHOR    => 'darren chamberlain <darren@cpan.org>',
    ABSTRACT  => "printf-style formatting capabilities with arbitrary format definitions",
  );
}

WriteMakefile(
    'NAME'         => __PACKAGE__,
    'VERSION_FROM' => "Format.pm",
    @ppd,
);


sub MY::postamble {
  return '' unless $] >= 5.00503;
<<'PPD';

dist : ppd

PPD
}

