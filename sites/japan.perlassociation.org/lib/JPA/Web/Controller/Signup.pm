# $Id$

package JPA::Web::Controller::Signup;
use Moose;
use namespace::clean -except => qw(meta);

BEGIN { extends 'Pixis::Web::Controller::Signup' }

sub _build_steps {
    return [
        qw(start address commit send_activate activate)
    ]
}

# Signup overview
#   1 - you're already a pixis user. good.
#   2 - verify addresses and such. these are not required for pixis
#       itself, but is required for JPA
#   3 - do a pre-registration. Insert into database, but
#       the payment status is "unpaid"
#
#   Path 1: paypal (or some other online, synchronous payment)
#   4A  - upon verfication form paypal, set the status.
#         you're done. (XXX - admin may want notification)
#
#   Path 2: bank transfer, convenience stores, etc.
#   4B - verify payment by hand (how unfortunate).
#        We need an admin view for this

sub check_jpa {
    my ($self, $c) = @_;

    # What, you're logged int?
    if ($c->user_exists) {
        # What, you're already a member?!
        if ($c->registry(api => 'JPAMember')->load_from_member({ member_id => $c->user->id })) {
            return 1;
        }
    }
    return 0;
}

sub contd :Local :Args(1) {
    my ($self, $c, $subsession) = @_;
    $c->stash->{subsession} = $subsession;
}

sub jpa_basic
    :Path('jpa/basic')
    :Args(0)
    :FormConfig('signup/jpa_basic')
{
    my ($self, $c) = @_;

#    $c->forward('/auth/assert_logged_in') or return;

    my $form = $c->stash->{form};

#    my $user = $c->registry(api => 'Member')->find($c->user->id);
#    $form->model->default_values( $user );
    if ($form->submitted_and_valid) {
        my $hash = $c->generate_session_id;
        my $params = $form->params;
        # remove extraneous stuff
        delete $params->{submit};

        $c->session->{jpa_signup}->{$hash} = $params;
        # needs to know where to go next
        my $next_uri =
            $params->{membership} eq 'JPA-0002' ?
                'confirm_basic' :
                'payment_choice'
        ;
        $c->res->redirect($c->uri_for($next_uri, $hash));
    }
}

sub confirm_basic :Local :Args(1) {
    my ($self, $c, $session) = @_;

    $c->forward('/auth/assert_logged_in') or return;
    if( !($c->stash->{confirm} = $c->session->{jpa_signup}->{$session})) {
        $c->res->redirect($c->uri_for('', 'signup'));
        return;
    }
    ;
    $c->stash->{subsession} = $session;
}

sub payment_choice :Local :Args(1) :FormConfig {
    my ($self, $c, $session) = @_;

    $c->forward('/auth/assert_logged_in') or return;
    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        my $membership = $c->session->{jpa_signup}->{$session}->{membership} .= '-' . $form->param('payment');

        my $item = $c->registry(api => 'PurchaseItem')->find($membership);
        if (! $item) {
            die "Could not find proper item: $membership";
        }

        $c->session->{jpa_signup}->{$session}->{item_price} = $item->price;
        $c->res->redirect($c->uri_for('/signup/confirm_basic', $session));
    }
}

sub commit_basic :Local :Args(1) {
    my ($self, $c, $session) = @_;
    $c->forward('/auth/assert_logged_in') or return;

    my $params;
    if( !($params = delete $c->session->{jpa_signup}->{$session})) {
        $c->res->redirect($c->uri_for('', 'signup'));
        return;
    }
    # commit this basic information.
    $params->{member_id} = $c->user->id;
    my ($jpa_member, $order) = $c->registry(api => 'JPAMember')->create($params);

    $c->stash->{order} = $order;
    $c->stash->{jpa_member} = $jpa_member;
}

sub payment :Local :Args(0) {
    my ($self, $c) = @_;
    $c->forward('/auth/assert_logged_in') or return;
}

1;