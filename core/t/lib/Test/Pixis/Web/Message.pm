package Test::Pixis::Web::Message;
use Moose;
use utf8;

BEGIN {
    extends 'Test::Pixis::Fixture';
    with 
        'Test::Pixis::Setup::Basic',
        'Test::Pixis::Setup::Schema',
        'Test::Pixis::Web::Common',
    ;
}

sub send_message :Test :Plan(1) {
    my ($self, $from, $to) = @_;
    my $mech = $self->logged_in_mech($from);
    $mech->get_ok('/message');

}

sub read_message :Test :Plan(1) {
    my ($self, $reader, $sender) = @_;

}

sub cant_read_message :Test :Plan(1) {
    my ($self, $reader, $sender) = @_;

}

__PACKAGE__->meta->make_immutable;

1;
