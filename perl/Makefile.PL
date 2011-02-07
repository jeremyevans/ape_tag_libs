use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'ApeTag',
    AUTHOR              => 'Jeremy Evans <code@jeremyevans.net>',
    VERSION_FROM        => 'lib/ApeTag.pm',
    ABSTRACT_FROM       => 'lib/ApeTag.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', TARFLAGS => '-cvhf' },
    clean               => { FILES => '' },
);
