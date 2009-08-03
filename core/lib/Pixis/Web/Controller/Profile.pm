package Pixis::Web::Controller::Profile;
use Moose;
use namespace::clean -except => qw(meta);
use utf8;
use YAML::Syck ();
use Data::Visitor::Callback;

BEGIN { 
    extends qw(Pixis::Web::ControllerBase);
}
with 'Pixis::Web::ControllerBase::WithSubsession';

has '+default_auth' => (
    default => 1
);

sub index
    :Local
    :Path('')
    :Args(0)
{
    my ( $self, $c ) = @_;
    my $form = $self->form($c);
    $c->stash->{form} = $form;
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
    return;
}

sub create
    :Chained('profile_type')
    :Args
{
    my ( $self, $c, $subsession ) = @_;

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
    my $form = $self->form($c, "profile/create_$type");
    $form->action($c->uri_for('type', $type, 'create', $subsession || ()));
    my $subsession_hash;
    if ($subsession) {
        $subsession_hash = $self->get_subsession($c, $subsession);
    }

    if ($subsession_hash) {
        $form->default_values($subsession_hash);
    }

    $c->stash->{form} = $form;

    if ($form->submitted_and_valid) {
        my $p = $subsession_hash || {};
        my $params = $form->params;
        $p->{$_} = $params->{$_} for keys %$params;
        delete $p->{submit};
        $subsession = $self->new_subsession($c, $p) unless $subsession;
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
    $c->stash->{next_url} = $c->uri_for('type', $type, 'create', 'commit', $subsession);
    $c->stash->{back_url} = $c->uri_for('type', $type, 'create', $subsession);
    $c->stash->{template} = "profile/confirm.tt";
    $c->stash->{subsession} = $subsession;
    $c->stash->{profile}  = $self->get_subsession($c, $subsession);
    return;
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

    $c->stash(profile => $profile);
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
    :Args
{
    my ( $self, $c, $subsession ) = @_;

    if (! $self->is_owner($c)) {
        return $c->res->redirect($c->uri_for($c->stash->{profile}->id));
    }
    my $api = $c->registry(api => 'Profile');

    my $type = $api->detect_type($c->stash->{profile})->name;
    my $form = $self->form($c, "profile/create_$type");
    $c->stash->{form} = $form;

    my $subsession_hash = $self->get_subsession($c, $subsession);
    if ($subsession_hash) {
        $form->default_values($subsession_hash);
    } else {
        $form->model->default_values($c->stash->{profile});
    }

    if ($form->submitted_and_valid) {
        my $p = $subsession_hash || {};
        my $params = $form->params;
        delete $params->{submit};
        $p->{$_} = $params->{$_} for keys %$params;
        $subsession = $self->new_subsession($c, $p) unless $subsession;
        $c->res->redirect($c->uri_for($c->stash->{profile}->id, 'edit', 'confirm', $subsession) );
    }
    return ();
}

sub edit_confirm
    :Chained('load_profile')
    :PathPart('edit/confirm')
    :Args(1)
{
    my ($self, $c, $subsession) = @_;

    $c->stash(
        next_url     => $c->uri_for($c->stash->{profile}->id, 'edit', 'commit', $subsession),
        back_url     => $c->uri_for($c->stash->{profile}->id, 'edit', $subsession),
        profile      => $self->get_subsession($c, $subsession),
        profile_type =>
            $c->registry(api => 'Profile')->detect_type($c->stash->{profile})->name,
        subsession   => $subsession,
        template     => "profile/confirm.tt",
    );
    return;
}

sub edit_commit
    :Chained('load_profile')
    :PathPart('edit/commit')
    :Args(1)
{
    my ($self, $c, $subsession) = @_;

    my $api = $c->registry(api => 'Profile');
    my $hash = $self->get_subsession($c, $subsession);
    $hash->{member_id} = $c->user->id;
    $hash->{profile_id} = $c->stash->{profile}->id;

    my $profile = $api->update( $hash );
    $self->delete_subsession($c, $subsession);

    return $c->res->redirect($c->uri_for($profile->id));
}

sub delete
    :Chained('load_profile')
    :PathPart('delete')
    :Args(0)
{
    my ( $self, $c ) = @_;

    if (! $self->is_owner($c)) {
        return $c->res->redirect($c->uri_for($c->stash->{profile}->id));
    }

    my $form = $self->form($c);
    $c->stash( form => $form );
    if ($c->stash->{form}->submitted_and_valid) {
        $c->registry(api => 'Profile')->delete({
            member_id => $c->user->id,
            profile_id => $c->stash->{profile}->id
        });
        $c->res->redirect($c->uri_for('/member/settings'));
    }
    return ();
}

sub photo
    :Chained('load_profile')
{
    my ($self, $c) = @_;

    my $photo = Pixis::Registry->get(api => 'Profile')->get_photo( $c->stash->{profile}->id );
    if (! $photo) {
        Pixis::Web::Exception::FileNotFound->throw();
    }

    my $res = $c->res;
    $res->content_type( $photo->content_type );
    $res->body( $photo->data );
}

sub photo_upload
    :Chained('load_profile')
    :PathPart('photo/upload')
{

    my ($self, $c) = @_;

    if ($c->stash->{profile}->member_id ne $c->user->id) {
        Pixis::Web::Exception::AccessDenied->throw();
    }

    my $form = $self->form($c);
    $c->stash->{form} = $form;
    if ($form->submitted_and_valid) {
        my $file = $form->param_value('file');
        $c->registry(api => 'Profile')->set_photo( {
            profile_id => $c->stash->{profile}->id,
            filename  => $file->tempname,
            content_type => $file->type,
        });
    }
}

1;

