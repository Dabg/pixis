package Pixis::Web::Controller::Auth;
use Moose;
use namespace::clean -except => qw(meta);

BEGIN { extends 'Pixis::Web::ControllerBase' }

has '+default_auth' => (default => 0);
has 'default_redirect' => (is => 'ro', isa => 'Str');

sub fail
    :Private
{
    my ($self, $c) = @_;
    $c->res->code(403);
    $c->res->body("You don't have permission to use this resource");
    return ();
}

sub assert_logged_in
    :Private
{
    my ($self, $c) = @_;
    if (! $c->user_exists) {
        $c->session->{next_uri} = $c->req->uri;
        $c->res->redirect($c->uri_for('/auth/login'));
        return ();
    }
    $c->log->debug("user " . $c->user->email . " asserted")
        if $c->debug;
    return 1;
}

sub assert_roles
    :Private
{
    my ($self, $c, @args) = @_;

    $self->assert_logged_in($c) or return ();
    if (! $c->check_user_roles(@args)) {
        $c->detach('/auth/fail');
        return ();
    }
    return 1;
}

sub login
    :Local
{
    my ($self, $c) = @_;

    my $form = $self->form($c);
    $c->stash->{form} = $form;

    if ($form->submitted_and_valid) {
        my $auth_ok = $c->forward('/auth/authenticate', [ 
            $form->param('email'), $form->param('password')
        ] ) && !@{$c->error};
        if ($auth_ok) {
            my $next = URI->new(
                $c->session->{next_uri} ||
                $form->param('next') 
            );
            $next->scheme(undef);
            if ($next->can('host_port')) {
                $next->host(undef);
                $next->port(undef);
            }

            $c->res->redirect(
                $c->uri_for(
                    "$next" || 
                    $self->default_redirect() ||
                    ('/member', $c->user->id)
                )
            );
            return;
        }

        # if you got here, the login was a failure
        $form->form_error_message( 
            $c->localize("Authentication failed"));
        $form->force_error_message(1);
    }
    return ();
}

sub authenticate :Private {
    my ($self, $c, $email, $password, $realm) = @_;
    $realm ||= 'members';
    my ($auth) = Pixis::Registry->get(api => 'MemberAuth')->load_auth({
        email => $email,
        auth_type => 'password'
    });
    $c->log->debug("Loaded auth information for $email (" . ($auth || ('null')) . ")") if $c->debug;

    # if no auth, then you're no good
    if ($auth) {
        # okie dokie, remember the milk, and load a resultset
        # XXX - there *HAS* to be a better way

        my $member = Pixis::Registry->get(api => 'Member')->load_from_email($email);
        if ($member) {
            $member->password($auth->auth_data);
            my $dummy = Pixis::AuthWorkAround->new($member);

            $c->log->debug("Authenticating against user $member") if $c->debug;
            return $c->authenticate({ password => $password, dbix_class => { resultset => $dummy } }, $realm);
        }
    }
    return ();
}

sub openid
    :Local
{
    my ($self, $c) = @_;

    my $form = $self->form($c);
    $c->stash->{form} = $form;
    if ($c->req->param('openid-check')) {
        if ($c->authenticate({}, 'openid')) {
            # here's the tricky bit. OpenID sign-on is a two phase thing.
            # we now know that the remote openid provider has authenticated
            # this guy, but we don't know if he's in our books.

            my ($auth) = Pixis::Registry->get(api => 'MemberAuth')->load_auth(
                {
                    auth_type => 'openid',
                    auth_data => $c->req->param('openid.identity')
                },
            );
            if ($auth) {
                $c->user( Pixis::Registry->get(api => 'Member')->load_from_email($auth->email) );

                $c->res->redirect(
                    $c->session->{next_uri} ||
                    $c->uri_for('/member', $c->user->id)
                );
                return;
            }
        }
    }
    if ($form->submitted_and_valid) {
        if ($c->authenticate({ openid_identifier => $form->param('openid_identifier') }, 'openid')) {
            $c->res->redirect(
                $c->session->{next_uri} ||
                $c->uri_for('/member', $c->user->id)
            );
            return;
        }
    }
    return ();
}

sub logout :Local {
    my ($self, $c) = @_;

    $c->delete_session;
    $c->res->redirect($c->uri_for('/'));
    return ();
}

package Pixis::AuthWorkAround; ## no critic
# XXX - TODO Create a C::Auth::Store subclass that doesn't require
# this horrible, horrible workaround
use strict;
use warnings;
sub new { return bless [ $_[1] ], $_[0] } ## no critic
sub first { return $_[0]->[0] } ## no critic

1;

__END__

=head1 NAME

Pixis::Web::Controller::Auth - Authentication

=head1 SYNOPSIS

    $c->forward('/auth/assert_logged_in');
    $c->forward('/auth/assert_roles', [ $role1, $role2, ... ]);
    $c->forward('/auth/authenticate', [ $user, $password ]);

=head1 PUBLIC ACTIONS

=head1 /auth/login

Displays, and handles user login

=head2 /auth/logout

Handles user logout

=head1 PRIVATE ACTIONS

=head2 /auth/assert_logged_in

Makes sure that we have an authenticated user. If not, will automatically 
redirect to /auth/login, so it is safe to return if this action returns false.

Returns true on success.

=head2 /auth/assert_roles [ @roles ]

Makes sure that we have an authenticated user, and that the user is of a given
role. If not authenticated, then results in the same effect as calling
C<assert_logged_in>. If authenticated and the role is not fulfilled, displays
a 403 error. 

Returns true on success.

=cut