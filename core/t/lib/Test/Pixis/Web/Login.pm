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

sub signin_with_duplicate_email : Test : Plan(6) {
    my ($self, $args ) = @_;
    my $mech = $self->reset_mech;

    $mech->get_ok('/');
    $mech->follow_link_ok({text => 'ログイン'});
    $mech->follow_link_ok({text_regex => qr/新規登録/});
    $mech->submit_form_ok(
        {
            form_number => 1,
            fields => $args,
            button => 'submit',
        },
        "新規登録ボタン",
    );
    $mech->content_like(qr{form_error_message});
    $mech->content_like(qr{使用されたメールアドレスはすでに登録されています});
}

sub activate_with_invalid_token : Test :Plan(3) {
    my ($self,$args) = @_;
    my $mech = $self->reset_mech;
    $mech->get_ok("/signup/activate?email=$args->{email}&token=brabbrabrabrabrabrabrabrabrabrabrabrabra");
    $mech->content_like(qr{form_error_message});
    $mech->content_like(qr{指定されたユーザーは存在しませんでした});
}

__PACKAGE__->meta->make_immutable;
