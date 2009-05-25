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

sub create : Test : Plan(6) {
    my ($self, $args) = @_;
    my $mech = $self->mech;
    $mech->get_ok('/member/settings');
    $mech->follow_link_ok({url_regex => qr{/profile/create}});
    $mech->submit_form_ok(
        {
            form_number => 1,
            fields => $args,
            button => 'submit',
        }
    );
    like $mech->uri->path, qr{/profile/\d+};
    $mech->content_like(qr{$args->{bio}});
    ok $mech->find_link(text_regex => qr{$args->{name}});
}

sub edit : Test : Plan(7) {
    my ($self, $prev, $next) = @_;
    my $mech = $self->mech;
    $mech->get_ok('/member/settings');
    $mech->follow_link_ok(
        {
            text => $prev->{name},
            url_regex => qr{/profile/\d+/edit},
        }
    );
    like $mech->uri->path, qr{/profile/\d+/edit};
    $mech->submit_form_ok(
        {
            form_number => 1,
            fields => $next,
            button => 'submit',
        }
    );
    like $mech->uri->path, qr{/profile/\d+};
    $mech->content_like(qr{$next->{bio}});
    ok $mech->find_link(text_regex => qr{$next->{name}});
}

1;
