
package Pixis::Plugin::Event;
use Moose;

with 'Pixis::Plugin';

has '+extra_api' => (
    default => sub {
        [ qw(Event EventDate EventRegistration EventSession EventTrack EventTicket) ]
    }
);

after register => sub {
    my $registry = Pixis::Registry->instance;
    my $c = $registry->get(pixis => 'web');

    my $left = $c->model('Widget')->load('LeftNavigation');
    $left->item_add(
        { id => 'events', uri => '/event', text => $c->localize('Event') }
    );
};

__PACKAGE__->meta->make_immutable;