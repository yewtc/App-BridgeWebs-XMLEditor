use 5.036;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'App::BridgeWebs::XMLEditor',
    AUTHOR           => 'BridgeWebs contributors',
    ABSTRACT         => 'GTK3 editor and library for BridgeWebs USEBIO XML bridge sessions',
    VERSION_FROM     => 'lib/BridgeWebs/Session.pm',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.036',
    EXE_FILES        => ['script/bridgewebs-xml-editor'],
    META_MERGE       => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/bridgewebs/App-BridgeWebs-XMLEditor.git',
                web  => 'https://github.com/bridgewebs/App-BridgeWebs-XMLEditor',
            },
        },
        optional_features => {
            gui => {
                description => 'GTK3 graphical editor',
                prereqs       => {
                    runtime => {
                        requires => {
                            Gtk3 => 0,
                        },
                    },
                },
            },
        },
    },
    PREREQ_PM => {
        'XML::Simple' => '2.18',
    },
    TEST_REQUIRES => {
        'Test::More' => '0.98',
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
    clean => { FILES => 'App-BridgeWebs-XMLEditor-* cover_db blib pm_to_blib Makefile.old' },
);
