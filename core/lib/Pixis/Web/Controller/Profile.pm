package Pixis::Web::Controller::Profile;
use Moose;
use namespace::clean -except => qw(meta);
use utf8;
use YAML::Syck ();
use Data::Visitor::Callback;

BEGIN { 
    extends qw(Catalyst::Controller::HTML::FormFu Pixis::Web::ControllerBase);
    with 'Pixis::Web::ControllerBase::WithSubsession';
}

has '+default_auth' => (
    default => 1
);

sub index : Local :Path('') :Args(0) :FormConfig {
    my ( $self, $c ) = @_;
    my $form = $c->stash->{form};
    if ( $form->submitted_and_valid ) {
        my @fields = qw(display_name bio);

        my $like = '%'.$form->param_value('q').'%';
        my @profiles = $c->registry(api => 'Profile')->search(
            [
                map { ($_ => { -like => $like }) } @fields
            ]
        );
        $c->stash->{profiles} = \@profiles;
    }
    return ();
}

sub profile_type
    :Chained
    :PathPart('profile/type')
    :CaptureArgs(1)
{
    my ($self, $c, $type) = @_;
    # Make sure this is allowed
    my $api = $c->registry(api => 'Profile');
    if (! $api->is_supported( $type )) {
        $c->detach('/default');
        return;
    }

    $c->stash->{profile_type} = $type;
}

sub create
    :Chained('profile_type')
    :Args(0)
{
    my ( $self, $c ) = @_;

    my $type = $c->stash->{profile_type};

    my ($profile) = $c->registry(api => 'Profile')->load_from_member({
        member_id => $c->user->id,
        type      => $type
    });
    if ($profile) {
        $c->stash(
            template => 'error.tt',
            error    => {
                safe_message => 1,
                message => "You already have a $type profile"
            }
        );
        return;
    }

    # ok, attempt to load the form
    my $form = $self->form;
    $form->load_config_filestem("root/forms/profile/create_$type");
    $form->action($c->uri_for('type', $type, 'create'));
    $form->process;

    $c->stash->{form} = $form;

    if ($form->submitted_and_valid) {
        my $p = $form->params;
        delete $p->{submit};
        my $subsession = $self->new_subsession($c, $p);
        $c->res->redirect($c->uri_for('type', $type, 'create', 'confirm', $subsession) );
    }
    return;
}

sub create_confirm
    :Chained('profile_type')
    :PathPart('create/confirm')
    :Args(1)
{
    my ($self, $c, $subsession) = @_;

    my $type = $c->stash->{profile_type};
    $c->stash->{template} = "profile/confirm_$type.tt";
    $c->stash->{subsession} = $subsession;
    $c->stash->{profile}  = $self->get_subsession($c, $subsession);
}

sub create_commit
    :Chained('profile_type')
    :PathPart('create/commit')
    :Args(1)
{
    my ($self, $c, $subsession) = @_;

    my $type = $c->stash->{profile_type};
    my $api = $c->registry(api => 'Profile');
    my $hash = $self->get_subsession($c, $subsession);
    $hash->{member_id} = $c->user->id;

    my $profile = $api->create_type( $type, $hash );
    $self->delete_subsession($c, $subsession);

    return $c->res->redirect($c->uri_for($profile->id));
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

sub is_owner {
    my ($self, $c) = @_;
    my $profile = $c->stash->{profile};
    return $profile->member_id == $c->user->id
}

sub edit
    :Chained('load_profile')
    :PathPart('edit')
    :Args(0)
    :FormConfig
{
    my ( $self, $c ) = @_;

    if (! $self->is_owner($c)) {
        return $c->res->redirect($c->uri_for($c->stash->{profile}->id));
    }

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

