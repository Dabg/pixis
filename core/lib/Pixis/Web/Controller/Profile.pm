package Pixis::Web::Controller::Profile;
use Moose;
use namespace::clean -except => qw(meta);

BEGIN { extends 'Catalyst::Controller::HTML::FormFu' }

use utf8;

sub auto :Private {
    my ( $self, $c ) = @_;
    return 1;
}

sub load_member : Chained : PathPart('profile') : CaptureArgs(1) {
    my ($self, $c, $id) = @_;

    my $api = $c->registry(api => 'Profile');
    my $profile = $api->find($id);
    if (! $profile) {
        $c->forward('/default');
        return;
    }
    $c->stash->{profile} = $profile;
    return ();
}

sub view : Chained('load_member') : PathPart('') Args(0) {
    my ($self, $c) = @_;
    return ();
}

sub edit :Local :FormConfig {
    my ( $self, $c ) = @_;

    my $form = $c->stash->{form};
    my $api = $c->registry(api => 'Profile');
    my $existing = $api->find({member_id => $c->user->id});
    $form->model->default_values($existing) if $existing;
    if ($form->submitted_and_valid) {
        my $profile = $api->update_from_form( $c->user, $form );
        $c->res->redirect($c->uri_for($profile->id));
    }
    return ();
}

1;

