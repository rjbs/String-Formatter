use strict;
use ExtUtils::MakeMaker;

my %clean = (
    'FILES' => '$(DISTVNAME).tar$(SUFFIX)'
);

WriteMakefile(
    'NAME'      => 'String::Format',
    'VERSION'   => '1.14',
    'clean'     => \%clean,
);
