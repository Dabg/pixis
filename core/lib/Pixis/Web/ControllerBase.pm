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

sub api {
    return Pixis::Registry->get(api => $_[1]);
}

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

__END__

=head1 NAME

Pixis::Web::ControllerBase - Base Controller Class

=head1 SYNOPSIS

    package MyApp::Controller::Foo;
    use Moose;
    use namespace::clean -except => qw(meta);
    BEGIN { extends 'Pixis::Web::ControllerBase' }

=head1 CONFIGURATION

    # every controller derived from Pixis::Web::ControllerBase can be
    # configured for authentication
    Controller::Open:
        default_auth: 0   # no authentication

    Controller::Closed:
        default_auth: 1   # do authentication

    Controller::AdminOnly
        default_auth:
            - admin       # Catalyst::Plugin::Authorization::Role role

    Controller::WithExceptions
        default_auth: 1   # require auth by default
        auth_info:
            no_auth: 0    # bu no_auth action does not require auth

=head2 ACTIONS

=head2 auto

Does automatic check for authentication. If authentication is required, then
checks if the user is logged in via /auth/assert_logged_in

=head1 METHODS

=head2 requires_auth($action)

Checks if the specified action require authentication

=head2 form($c [, [ $filename | \%args ]])

Returns a HTML::FormFu object. The object is already initialized, ready to be
checked with submitted_and_valid().

When called with just the context object, looks for a form config file based
on the current action name.

    sub index :Index {
        my ($self, $c) = @_;

        $self->form($c); # attempts to load index.yml (or whatever file format)
    }

When called with a context object and a scalar, attempts to load the named
config file

    sub index :Index {
        my ($self, $c) = @_;

        $self->form($c, 'foo/bar/baz');
            # attempts to load foo/bar/baz.yml (or whatever file format)
    }

and finally, if you pass a hashref, you can expect it to be passed to 
HTML::FormFu's constructor. If you include a filename argument, this is
taken as the config file name. Otherwise, the action name is used, just
like the default single argument case.

=cut
