use strict;
use ExtUtils::MakeMaker;

my %clean = (
    'FILES' => '$(DISTVNAME).tar$(SUFFIX)'
);

WriteMakefile(
    'NAME'          => 'String::Format',
    'VERSION_FROM'  => 'Format.pm',
    'clean'         => \%clean,
    'PREREQ_PM'     => {
        'Test::More'    => 0.00,
        'Params::Util'  => '0.12',  # HASHLIKE; also required by Sub::Exporter
        'Sub::Exporter' => '0.980', # bug fixes
    },
);
