package Test::Pixis::Web::Profile;
use utf8;
use Moose;

BEGIN {
    extends 'Test::Pixis::Fixture';
    with
        'Test::Pixis::Setup::Basic',
        'Test::Pixis::Setup::Schema',
        'Test::Pixis::Web::Common',
    ;
}

sub create : Test : Plan(4) {
    my ($self, $args) = @_;
    my $mech = $self->mech;
    $mech->get_ok('/profile/edit');
    $mech->submit_form_ok(
        {
            form_number => 1,
            fields => $args,
            button => 'submit',
        }
    );
    is $mech->uri->path, '/profile/1';
    $mech->content_like(qr{$args->{bio}});
}

1;
