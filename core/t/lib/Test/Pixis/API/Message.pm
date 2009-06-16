
package Test::Pixis::API::Message;
use Moose;
use Test::Exception;
use Test::More;

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
    my ($self, $args) = @_;
    my $api = Pixis::Registry->get(api => 'message');

    my $from = $args->{from};
    my $to   = $args->{to};
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

sub check_mailbox :Test :Plan(2) {
    my ($self, $args) = @_;
    my $api = Pixis::Registry->get(api => 'message');

    my $profile = $args->{profile};
    if (! blessed $profile) {
        $profile = $self->get_profile($profile);
    }

    my $tag = $args->{tag} || 'Inbox';
    lives_ok {
        my @message = $api->load_from_tag({
            profile_id => $profile->id,
            tag        => 'Inbox',
        });

        is( scalar @message, $args->{count}, "I have " . scalar @message . " messages (wanted: $args->{count})" );
    } "message retrieval lives ok";
}

__PACKAGE__->meta->make_immutable();


