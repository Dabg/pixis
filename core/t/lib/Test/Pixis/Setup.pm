package Test::Pixis::Setup;
use parent 'Test::FITesque::Fixture';
use Moose::Role;

use Test::More;
use Test::Pixis;
use Pixis::CLI::SetupDB;


BEGIN {
    my $builder = Test::More->builder;
    binmode($builder->output, ':utf8');
    binmode($builder->failure_output, ':utf8');
    binmode($builder->todo_output, ':utf8');
}

has mech => (
    is => 'rw',
    isa => 'Test::WWW::Mechanize::Catalyst',
    lazy_build => 1,
);

sub _build_mech { 
    my $mech = Test::WWW::Mechanize::Catalyst->new;
    $mech->default_headers->push_header('Accept-Language' => 'ja');
    return $mech;
}

sub setup_db {
    my $t = Test::Pixis->instance();

    if (! $ENV{PIXIS_SKIP_SETUPDB}) {
    my $connect_info = $t->config->{'Schema::Master'}->{connect_info};

    Pixis::CLI::SetupDB->new(
        dsn => $connect_info->[0],
        username => $connect_info->[1],
        password => $connect_info->[2] || '',
        drop => 1,
    )->run();
    }
}

sub setup_web : Test : Plan(1) {
    $ENV{CATALYST_CONFIG} = 't/conf/pixis_test.yaml';
    use_ok( 'Test::WWW::Mechanize::Catalyst', 'Pixis::Web' );
}

1;
