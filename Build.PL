use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Sub::Starter',
    license             => 'GPL v3',
    dist_author         => 'Shawn H Corey <SHCOREY@cpan.org>',
    dist_version_from   => 'lib/Sub/Starter.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Sub-Starter-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();