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

sub send_message :Test :Plan(7) {
    my ($self, $from, $to, $mail) = @_;
    my $mech = $self->logged_in_mech($from);
    $mech->get_ok('/profile');
    $mech->submit_form_ok( {form_number => 1, button => 'submit'} );
    $mech->follow_link_ok( {text => $to->{nickname}} );
    $mech->follow_link_ok( {url_regex => qr{/message/create}} );
    $mech->submit_form_ok(
        {
            form_number => 1,
            fields => $mail,
            button => 'submit',
        }
    );
    $mech->content_like(qr{$mail->{subject}});
    $mech->content_like(qr{$mail->{body}});
    $mech->content_like(qr{$to->{nickname}});
}

sub read_message :Test :Plan(5) {
    my ($self, $reader, $sender, $mail) = @_;
    my $mech = $self->logged_in_mech($reader);
    $mech->get_ok('/member/home');
    $mech->get_ok('/message');
    $mech->follow_link_ok({text => $mail->{subject}});
    $mech->content_like(qr{$sender->{nickname}});
    $mech->content_like(qr{$mail->{subject}});
    $mech->content_like(qr{$mail->{body}});
}

sub cant_read_message :Test :Plan(1) {
    my ($self, $reader, $sender) = @_;

}

__PACKAGE__->meta->make_immutable;

1;
