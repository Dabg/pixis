package Pixis::Web::Controller::Event::Payment::Paypal;
use Moose;
use namespace::clean -except => qw(meta);

BEGIN { extends 'Pixis::Web::Controller::Payment::Paypal' };

has '+complete_url' => (
    default => '/event/payment/paypal/complete'
);

sub complete :Local {
    my ($self, $c) = @_;

    $self->SUPER::complete($c);

    # if the order is complete, activate the registration status
    my $api = $c->registry(api => 'EventRegistration');
    my $registration = $api->load_from_order(
        {
            order_id => $c->stash->{order}->id,
            member_id => $c->user->id,
        }
    );
    $api->activate({ id => $registration->id });

    $c->stash->{template} = 'payment/paypal/complete.tt';
    return ();
}

1;
