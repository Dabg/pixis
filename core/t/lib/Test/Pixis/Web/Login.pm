package Test::Pixis::Web::Login;
use utf8;
use Moose;
use Email::Send::Test;

BEGIN
{
    extends 'Test::Pixis::Fixture';
    with 
        'Test::Pixis::Setup::Basic',
        'Test::Pixis::Setup::Schema',
        'Test::Pixis::Web::Common',
    ;
}

sub forgot_password : Test :Plan(9) {
    my ($self, $args) = @_;
    my $mech = $self->reset_mech;
    $mech->get_ok('/');
    $mech->follow_link_ok({text => 'ログイン'});
    $mech->follow_link_ok({text_regex => qr{忘}});
    Email::Send::Test->clear;
    $mech->submit_form_ok(
        {
            form_number => 1,
            fields => {
                email => $args->{email},
            },
            button => 'submit',
        }
    );
    my @emails = Email::Send::Test->emails;
    is scalar @emails, 1, 'activation mail sent';
    my $body = $emails[0]->body;
    ok( my ($activation_uri) = $body =~ m{http://localhost(/member/reset_password\S+)});
    $mech->get_ok($activation_uri); 
    $mech->submit_form_ok(
        {
            form_number => 1,
            fields => {
                email => $args->{email},
                password => $args->{password},
                password_check => $args->{password},
            },
            button => 'submit',
        }
    );
    $mech->follow_link_ok({text => 'ログアウト'});
}

sub reset_password_without_token : Test : Plan(3) {
    my ( $self, $args ) = @_;
    my $mech = $self->reset_mech;
    $mech->get_ok("/member/reset_password?email=$args->{email}");
    $mech->submit_form_ok(
        {
            form_number => 1,
            fields => {
                email => $args->{email},
                password => $args->{password},
                password_check => $args->{password},
            },
            button => 'submit',
        }
    );
    $mech->content_like(qr{form_error_message});
}

__PACKAGE__->meta->make_immutable;
