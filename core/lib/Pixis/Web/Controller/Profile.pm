package Pixis::Web::Controller::Profile;
use Moose;
use utf8;

BEGIN { extends 'Catalyst::Controller::HTML::FormFu' }

__PACKAGE__->config(
    params_ignore_underscore => 1,
);

sub auto :Private {
    my ( $self, $c ) = @_;
    return 1;
}

sub load_profile : Chained : PathPart('profile') : CaptureArgs(1) {
    my ($self, $c, $id) = @_;

    my $api = $c->registry(api => 'Profile');
    my $profile = $api->find($id);
    if (! $profile) {
        $c->forward('/default');
        return;
    }
    $c->stash->{profile} = $profile;
}

sub view : Chained('load_profile') : PathPart('') Args(0) {
    my ($self, $c) = @_;
}

sub edit :Chained('load_profile') : PathPart('edit') :Args(0) :FormConfig {
    my ( $self, $c ) = @_;

    my $form = $c->stash->{form};
    my $api = $c->registry(api => 'Profile');
    my $existing = $c->stash->{profile};
    $form->model->default_values($existing) if $existing;
    if ($form->submitted_and_valid) {
        my $args = $form->params;
        delete $args->{submit};
        my $profile = $api->update( $args );
        $c->res->redirect($c->uri_for($profile->id));
    }
}

sub create : Local :Args(0) {
    my ( $self, $c ) = @_;

    my $form = $self->form;
    $form->load_config_filestem('profile/edit');
    $form->process($c->req->params);
    $c->stash->{form} = $form;
    if ($form->submitted_and_valid) {
        my $api = $c->registry(api => 'Profile');
        my $args = $form->params;
        delete $args->{submit};
        delete $args->{id};
        $args->{member_id} = $c->user->id;
        my $profile = $api->create($args);
        $c->res->redirect($c->uri_for($profile->id));
    }
}

1;

