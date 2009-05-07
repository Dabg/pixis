package Test::Pixis::Setup::Mechanize;
use Moose::Role;
use parent 'Test::FITesque::Fixture';
use Test::More;
use Test::WWW::Mechanize::Catalyst;
use namespace::clean -except => qw(meta);
use MooseX::AttributeHelpers;

has mech => (
    is => 'rw',
    isa => 'Test::WWW::Mechanize::Catalyst',
    lazy_build => 1,
);

has seen_links => (
    metaclass => 'Collection::Hash',
    is => 'rw',
    isa => 'HashRef',
    required => 1,
    default => sub { +{} },
    provides => {
        get => 'get_seen_link',
        set => 'set_seen_link',
        clear => 'clear_seen_links',
    }
);

sub _build_mech { 
    my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'Pixis::Web');
    $mech->default_headers->push_header('Accept-Language' => 'ja');
    return $mech;
}

sub reset_mech {
    my $self = shift;
    $self->mech->cookie_jar({}); #reset cookies
    return $self->mech;
}

sub setup_web :Test :Plan(1) {
    $ENV{CATALYST_CONFIG} ||= 't/conf/pixis_test.yaml';
    use_ok( 'Pixis::Web' );
}

sub spider {
    my ($self, $link)  = @_;
    my $mech = $self->reset_mech;
    $mech->get_ok($link || '/');

    my @links = $mech->links();
    foreach my $link (@links) {
        next if $self->get_seen_link( $link->url );
        $self->set_seen_link($link->url, 1);
        $self->follow($link->url);
    }
}

1;
