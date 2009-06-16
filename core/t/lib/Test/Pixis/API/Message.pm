
package Test::Pixis::API::Message;
use Moose;
use Test::Exception;

BEGIN {
    extends 'Test::Pixis::Fixture';
    with 
        'Test::Pixis::Setup::Basic',
        'Test::Pixis::Setup::Schema',
    ;
}

sub setup {
    my $self = shift;

    my $registry = Pixis::Registry->instance();
    $registry->set(api => 'message', $self->api('Message'));
}

sub send_message :Test :Plan(1) {
    my ($self, $from, $to) = @_;
    my $api = Pixis::Registry->get(api => 'message');

    if (! blessed $from) {
        $from = $self->get_profile($from);
    }
    if (! blessed $to) {
        $to = $self->get_profile($to);
    }
    lives_ok {
        my $message = $api->create({
            from    => $from->id,
            to      => $to->id,
            # from Pulp Fiction
            subject => '愛しているよハニーバニー',
            body    => 'とりあえずこのレストランを強盗しよう',
        });
    } "message creation lives ok";
}

sub check_inbox {}

__PACKAGE__->meta->make_immutable();


