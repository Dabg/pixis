
package Test::Pixis::Web::Common;
use Moose::Role;
use utf8;
use parent 'Test::FITesque::Fixture';
use Test::More;

with 
    'Test::Pixis::Setup::Mechanize',
;


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

1;
