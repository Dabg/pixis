package Test::Pixis::Setup::Mechanize;
use Moose::Role;
use parent 'Test::FITesque::Fixture';
use namespace::clean -except => qw(meta);
use Test::More;
use Test::WWW::Mechanize::Catalyst;

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

sub reset_mech {
    my $self = shift;
    $self->mech->cookie_jar({}); #reset cookies
    return $self->mech;
}

sub setup_web : Test : Plan(1) {
    $ENV{CATALYST_CONFIG} = 't/conf/pixis_test.yaml';
    use_ok( 'Test::WWW::Mechanize::Catalyst', 'Pixis::Web' );
}

1;
