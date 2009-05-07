package Test::Pixis::Login;
use Moose;
with 
    'Test::Pixis::Setup::Basic',
    'Test::Pixis::Setup::Schema',
    'Test::Pixis::Setup::Mechanize',
;

use utf8;

use parent 'Test::FITesque::Fixture';

use Test::More;
use Test::Exception;
use Email::Send::Test;

sub signin : Test : Plan(13) {
    my ($self, $args) = @_;
    $args->{password_check} ||= $args->{password};
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
    unlike $mech->content, qr{form_error_message};
    $mech->submit_form_ok(
        {
            form_number => 1,
            button => 'submit',
        }
    );
    unlike $mech->content, qr{form_error_message};
    Email::Send::Test->clear;
    $mech->submit_form_ok(
        {
            form_number => 1,
            button => 'submit',
        }
    );
    unlike $mech->content, qr{form_error_message};
    my @emails = Email::Send::Test->emails;
    lives_and {
        is scalar @emails, 1, 'activation mail sent';
        my $body = $emails[0]->body;
        ok( my ($activation_uri) = $body =~ m{http://localhost(/signup/activate\S+)});
        $mech->get_ok($activation_uri); 
        ok $mech->find_link(text => 'ログアウト');
    } "email check all ok";
}

sub login : Test : Plan(4) {
    my ($self, $args) = @_;
    my $mech = $self->reset_mech;
    $mech->get_ok('/');
    $mech->follow_link_ok({text => 'ログイン'});
    $mech->submit_form_ok(
        {
            form_number => 1,
            fields => {
                email => $args->{email} || '',
                password => $args->{password} || '',
            },
            button => 'submit',
        }
    );
    ok $mech->find_link(text => 'ログアウト');
}

sub logout : Test : Plan(2) {
    my ($self, $args) = @_;
    my $mech = $self->mech;
    $mech->get_ok('/');
    $mech->follow_link_ok({text => 'ログアウト'});
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

1;
