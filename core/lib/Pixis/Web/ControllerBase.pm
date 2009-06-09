package Pixis::Web::ControllerBase;
use Moose;
use MooseX::AttributeHelpers;
use namespace::clean -except => qw(meta);

BEGIN { extends 'Catalyst::Controller' }

# Controller::Foo:
#   default_auth: 0 # No auth, allow anybody
# Controller::Bar:
#   auth_info:
#       an_action: [ 'admin' ] # require auth, and require admin role
#       another: 1 # require auth, but any auth user is ok

has default_auth => (
    is => 'ro',
    isa => 'Bool',
    default => 1,
);

has auth_info => (
    metaclass => 'Collection::Hash',
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1,
    provides => {
        exists => 'auth_info_exists',
        set => 'auth_info_set',
        get => 'auth_info_get',
    }
);

sub _build_auth_info { return {} }

sub requires_auth {
    my ($self, $name) = @_;

    if ($self->auth_info_exists($name)) {
        return $self->auth_info_get($name);
    }

    return $self->default_auth;
}

sub auto :Private {
    my ( $self, $c ) = @_;

    my $action = $c->action->name;

    my $authed = 0;
    my $roles = $self->requires_auth($action);
    if ($roles) {
        if (! $c->forward('/auth/assert_logged_in')) {
            return;
        }

        if (ref $roles eq 'ARRAY') {
            if (! $c->forward('/auth/assert_roles', $roles)) {
                return;
            }
        }
    }

    return 1;
}

sub form {
    my ($self, $c, $args) = @_;

    $args ||= {};
    my $filename;
    if (ref $args ) {
        $filename = delete $args->{filename};
    } else {
        $filename = $args;
        $args = {};
    }
    $filename ||= $c->action . "";
    my $form = $c->model('FormFu')->load( $filename, $args );

    $form->process($c->request);
    return $form;
}

1;
