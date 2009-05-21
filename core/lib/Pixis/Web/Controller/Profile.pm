package Pixis::Web::Controller::Profile;
use Moose;
use namespace::clean -except => qw(meta);
use utf8;

BEGIN { extends 'Catalyst::Controller::HTML::FormFu' }

sub auto :Private {
    my ( $self, $c ) = @_;
    $c->forward('/auth/assert_logged_in') or return;
    return 1;
}

sub index : Local :Path('') :Args(0) :FormConfig {
    my ( $self, $c ) = @_;
    my $form = $c->stash->{form};
    if ( $form->submitted_and_valid ) {
        my @profiles = $c->registry(api => 'Profile')->search(
            {
                name => {like => '%'.$form->param_value('q').'%'}
            }
        );
        $c->stash->{profiles} = \@profiles;
    }
    return ();
}

sub create : Local :Args(0) :FormConfig('profile/edit') {
    my ( $self, $c ) = @_;

    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        my $api = $c->registry(api => 'Profile');
        my $args = $form->params;
        delete $args->{submit};
        delete $args->{id};
        $args->{member_id} = $c->user->id;
        my $profile = $api->create($args);
        $c->res->redirect($c->uri_for($profile->id));
    }
    return ();
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
    return ();
}

sub view : Chained('load_profile') : PathPart('') Args(0) {
    my ($self, $c) = @_;
    return ();
}

sub edit :Chained('load_profile') : PathPart('edit') :Args(0) :FormConfig {
    my ( $self, $c ) = @_;

    $c->stash->{profile}->member_id == $c->user->id
        or return $c->res->redirect($c->uri_for($c->stash->{profile}->id));

    my $form = $c->stash->{form};
    $form->model->default_values($c->stash->{profile});
    my $api = $c->registry(api => 'Profile');
    if ($form->submitted_and_valid) {
        my $args = $form->params;
        delete $args->{submit};
        my $profile = $api->update( $args );
        $c->res->redirect($c->uri_for($profile->id));
    }
    return ();
}

sub delete : Chained('load_profile') :PathPart('delete') :Args(0) :FormConfig {
    my ( $self, $c ) = @_;

    $c->stash->{profile}->member_id == $c->user->id
        or return $c->res->redirect($c->uri_for($c->stash->{profile}->id));
    if ($c->stash->{form}->submitted_and_valid) {
        $c->registry(api => 'Profile')->delete($c->stash->{profile}->id);
        $c->res->redirect($c->uri_for('/member/settings'));
    }
    return ();
}

1;

