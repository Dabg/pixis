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

sub send_message :Test :Plan(8) {
    my ($self, $args) = @_;
    my $mech = $self->logged_in_mech($args->{from_user});
    $mech->get_ok('/profile');
    $mech->submit_form_ok( {form_number => 1, button => 'submit'} );
    $mech->follow_link_ok( {text => $args->{to_profile}->{name}} );
    $mech->follow_link_ok( {url_regex => qr{/message/create}} );
    $mech->submit_form_ok(
        {
            form_number => 1,
            fields => {
                %{$args->{mail}},
                from_profile => $args->{from_profile}->{name},
            },
            button => 'submit',
        }
    );
    $mech->content_like(qr!$args->{mail}->{subject}!);
    $mech->content_like(qr!$args->{mail}->{body}!);
    $mech->content_like(qr!$args->{to_profile}->{name}!);
}

sub read_message :Test :Plan(6) {
    my ($self, $args) = @_;
    my $mech = $self->logged_in_mech($args->{reader});
    $mech->get_ok('/member/home');
    $mech->get_ok('/message');
    $mech->follow_link_ok({text => $args->{mail}->{subject}});
    $mech->content_like(qr|$args->{from_profile}->{name}|);
    $mech->content_like(qr|$args->{mail}->{subject}|);
    $mech->content_like(qr|$args->{mail}->{body}|);
}

sub cant_read_message :Test :Plan(5) {
    my ($self, $args) = @_;
    my $mech = $self->logged_in_mech($args->{real_reader});
    $mech->get_ok('/member/home');
    $mech->get_ok('/message');
    $mech->follow_link_ok({text => $args->{mail}->{subject}});
    my $message_url = $mech->uri->path;
    my $bad_mech = $self->logged_in_mech($args->{reader});
    $bad_mech->get_ok($message_url);
    Test::More::is $bad_mech->uri->path, '/message';
}

__PACKAGE__->meta->make_immutable;

1;
