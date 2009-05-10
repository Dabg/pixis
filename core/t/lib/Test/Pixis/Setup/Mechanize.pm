package Test::Pixis::Setup::Mechanize;
use Moose::Role;
use parent 'Test::FITesque::Fixture';
use Test::More;
use Test::WWW::Mechanize::Catalyst;
#use Test::Pixis::Mechanize;
use LWP::Simple;
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
    my ($self) = @_;
    my $mech;
    if ($self->get_apache_test_server()) {
        $mech = Test::WWW::Mechanize::Catalyst->new;
        $mech->allow_external(1);
        $mech->host(Apache::TestRequest::hostport());
    }
    unless ($mech) {
        $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'Pixis::Web');
    }
    $mech->default_headers->push_header('Accept-Language' => 'ja');
    return $mech;
}

sub reset_mech {
    my $self = shift;
    $self->mech->cookie_jar({}); #reset cookies
    return $self->mech;
}

sub setup_web :Test :Plan(1) {
    my ($self) = @_;
    if (my $server = $self->get_apache_test_server()) {
        ok(LWP::Simple::get($server));
    } else {
        $ENV{CATALYST_CONFIG} ||= 't/conf/pixis_test.yaml';
        use_ok( 'Pixis::Web' );
    }
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

sub get_apache_test_server {
    my ($self) = @_;
    if (eval { require Apache::TestMM }) {
        my $baseurl = Apache::TestRequest::resolve_url('/');
        if (LWP::Simple::get($baseurl)) {
            $ENV{CATALYST_SERVER} = $baseurl;
            return $baseurl;
        }
    }
}

1;
