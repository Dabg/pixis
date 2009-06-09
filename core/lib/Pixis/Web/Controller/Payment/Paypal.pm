
package Pixis::Web::Controller::Payment::Paypal;
use Moose;
use namespace::clean -except => qw(meta);

BEGIN { extends qw(Pixis::Web::ControllerBase) }

has complete_url => (
    is => 'rw',
    default => 'complete',
);

has accept_url => (
    is => 'rw',
    default => 'accept',
);

has cancel_url => (
    is => 'rw',
    default => 'cancel'
);

has '+default_auth' => (default => 1);

sub initiate_purchase
    :Private
{
    my ($self, $c) = @_;

    my $order;
    my $form = $self->form($c, 'payment/paypal/purchase');
    $c->stash(form => $form);
    if ($form->submitted_and_valid) {
        ($order) = $c->registry(api => 'Order')->search(
            {
                id        => $form->param('order'),
                member_id => $c->user->id,
                status    => &Pixis::Schema::Master::Result::Order::ST_INIT,
            }
        );
    }

    if (! $order) {
        # XXX - huh?
        $c->log->debug("Order not found :(") if $c->log->is_debug;
        Pixis::Web::Exception->throw(
            safe_message => 1,
            message => "Requested order '" . $form->param('order') . "' was not found"
        );
    }

    my $args = {
        order_id    => $order->id,
        return_url  => $c->uri_for($self->accept_url, { order => $order->id }),
        cancel_url  => $c->uri_for($self->cancel_url, { order => $order->id }),
        amount      => $order->amount,
        member_id   => $c->user->id,
        description => $order->description
    };

    my $url = eval {
        local $SIG{__DIE__} = 'DEFAULT';
        $c->registry(api => 'payment' => 'paypal')->initiate_purchase($args);
    };
    if ($@) {
        $c->log->debug("Communication with Paypal failed: $@") if $c->log->is_debug;
        $c->detach('/error', "Communication with PayPal failed");
        return;
    }

    $c->res->redirect($url);
    return ();
}

sub complete_purchase
    :Private
{
    my ($self, $c, $args) = @_;

    eval {
        local $SIG{__DIE__} = 'DEFAULT';
        $c->registry(api => 'payment' => 'paypal')->complete_purchase($args);
    };
    if ($@) {
        $c->log->debug("Communication Paypal failed: $@") if $c->log->is_debug;
        $c->forward('/error', "Communication with PayPal failed");
        return;
    }

    $c->res->redirect($args->{return_url});
    return ();
}

sub index
    :Index
    :Args(0)
{
    my ($self, $c) = @_;
    $self->initiate_purchase($c);
    return ();
}

sub accept
    :Local {
    my ($self, $c) = @_;

    my $order;
    my $form = $self->form($c, 'payment/paypal/accept');
    $c->stash(form => $form);
    if ($form->submitted_and_valid) {
        $c->log->debug("Loading order for paypal_accept: " . $form->param('order')) if $c->log->is_debug;
        $order = $c->registry(api => 'Order')->find($form->param('order'));
    }

    if (! $order) {
        # XXX - huh?
        $c->log->debug("Order not found :(") if $c->log->is_debug;
        Pixis::Web::Exception->throw(
            safe_message => 1,
            message => "Requested order '" . $form->param('order') . "' was not found"
        );
        return;
    }

    # let the payment gateway do its thing. if it's okay, we shall proceed
    $c->controller('Payment::Paypal')->complete_purchase($c, {
        return_url  => $c->uri_for($self->complete_url, { order => $form->param('order') }) ,
        cancel_url  => $c->uri_for($self->cancel_url, { order => $c->req->param('order') }),
        price       => $order->amount,
        member_id   => $c->user->id,
        description => $order->description,
        ext_id      => $form->param('token'),
        txn_id      => $form->param('txn'),
        order_id    => $form->param('order'),
        payer_id    => $form->param('PayerID'),

    } );
    return ();
}

sub cancel
    :Local
{
    my ($self, $c) = @_;

    $c->controler('Payment::Paypal')->cancel($c, {
    } );
    return ();
}

sub complete
    :Local
{

    my ($self, $c) = @_;

    my $form = $self->form($c, 'payment/paypal/complete');
    $c->stash(form => $form);

    if (! $form->submitted_and_valid) {
        $c->forward('/error', 'unknown order');
    }

    $c->log->debug("Loading order for paypal_complete: " . $form->param('order')) if $c->log->is_debug;
    my $order = $c->registry(api => 'Order')->find($form->param('order'));
    $c->registry(api => 'order')->change_status(
        {
            order_id => $form->param('order'),
            status   => &Pixis::Schema::Master::Result::Order::ST_DONE,
        }
    );
    $c->stash->{order} = $order;
    return ();
}

1;
