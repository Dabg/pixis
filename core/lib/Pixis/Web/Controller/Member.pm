
package Pixis::Web::Controller::Member;
use Moose;
use namespace::clean -except => qw(meta);
use utf8;
use Digest::SHA1 ();

BEGIN {
    extends qw(Catalyst::Controller::HTML::FormFu Pixis::Web::ControllerBase);
}

has '+default_auth' => ( default => 1 );

sub _build_auth_info {
    return {
        forgot_password => 0,
        reset_password => 0,
    }
}

sub load_member
    :Chained
    :PathPart('member')
    :CaptureArgs(1)
{
    my ($self, $c, $id) = @_;

    my $api = $c->registry(api => 'Member');
    my $member = $api->find($id);
    if (! $member) {
        $c->forward('/default');
        return;
    }
    $c->stash->{member} = $member;

    $c->stash->{following} = $api->load_following($id);
    $c->stash->{followers} = $api->load_followers($id);
    return ();
}

sub home :Local {
    # XXX Later?
    my($self, $c) = @_;
    return $c->res->redirect($c->uri_for($c->user->id));
}

sub view
    :Chained('load_member')
    :PathPart(''):
    Args(0)
{
    my ($self, $c) = @_;

    {
        my $api = $c->registry(api => 'MemberNotice');
        # Check to see if we have notices
        $c->stash->{notices} =
            [ $api->load_from_member({ member_id => $c->user->id }) ];
    }

    {
        my $api = $c->registry(api => 'Member');
        # Load my latest activities
        $c->stash->{activities} = 
            [ $api->load_recent_activity( { member_id => $c->user->id } ) ];
    }

    return ();
}

# XXX - follow status
sub follow :Chained('load_member') :Args(0) {
    my ($self, $c) = @_;

    $c->registry(api => 'MemberRelationship')->follow($c->user, $c->stash->{member});
    $c->res->redirect($c->uri_for($c->stash->{member}->id));
    return ();
}

sub unfollow :Chained('load_member') :Args(0) {
    my ($self, $c) = @_;
    $c->registry(api => 'MemberRelationship')->unfollow($c->user, $c->stash->{member});
    $c->res->redirect($c->uri_for($c->stash->{member}->id));
    return ();
}

sub settings
    :Local
    :Args(0)
{
    my ($self, $c) = @_;

    $c->stash(
        widgets => [ 'Member::BasicSettings', 'Member::AuthSettings', 'Member::ProfileSettings' ],
    );
}

sub prepare_profiles { # XXX Refactor this to profile later
    my ($self, $c) = @_;

    my @profiles = $c->registry(api => 'Profile')
        ->load_from_member({ member_id => $c->user->id });

    $c->stash->{"profiles"} = [ @profiles ];
    return ();
}

sub settings_basic :Path('settings/basic') :Args(0) :FormConfig {
    my ($self, $c) = @_;

    my $form = $c->stash->{form};
    my $user = $c->registry(api => 'Member')->find($c->user->id);
    $form->model->default_values($user);
    if ($form->submitted_and_valid) {
        $c->registry(api => 'Member')->update_from_form($user, $form);
        if ($c->user->email ne $user->email) {
            # XXX - Hack to overcome Catalyst::Plugin::Authentication
            $c->session->{__user} = { $user->get_columns };
        }
        $c->res->redirect($c->uri_for('home'));
    }
    return ();
}

sub settings_auth :Path('settings/auth') :Args(0) :FormConfig {
    my ($self, $c) = @_;

    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        my ($auth) = $c->registry(api => 'MemberAuth')->load_auth(
            {
                email => $c->user->email,
                auth_type => 'password'
            }
        );

        my $password = $form->param('password');
        my $hashed = unpack('H*', Digest::SHA1->new()->add($password)->digest);
        if ($auth->auth_data ne $hashed ) {
            $form->form_error_message("現行パスワードが正しくありません");
            $form->force_error_message(1);
            return;
        }

        $c->registry(api => 'MemberAuth')->update_auth(
            {
                member_id => $c->user->id,
                auth_type => 'password',
                password  => $form->param('password_new')
            },
        );
        $c->res->redirect($c->uri_for('/member/settings'));
    }
    return ();
}

sub forgot_password :Local :Args(0) :FormConfig {
    my ( $self, $c ) = @_;

    $c->logout;

    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        my $api = $c->registry(api => 'Member');
        my $member = $api->forgot_password({email => $form->param_value('email')});
        if ($member) {
            $c->stash->{member} = $member; 
            my $body = $c->view('TT')->render($c, 'member/forgot_password_email.tt');
            $c->controller('Email')->send($c, {
                    header => {
                        To => $member->email,
                        From => 'no-reply@pixis.local',
                        Subject => 'パスワード再設定メール',
                    },
                    body => $body,
                }
            );
            $c->stash->{message} = 'email sent';
        } else {
            $form->form_error_message("your mail address not found.");
            $form->force_error_message(1);
        }
    }
    return ();
}

sub reset_password :Local :Args(0) :FormConfig {
    my ( $self, $c ) = @_;

    $c->logout;

    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        my $api = $c->registry(api => 'Member');
        my $member = $api->reset_password(
            {
                email => $form->param_value('email'),
                token => $form->param_value('token'),
            }
        );
        unless ($member) {
            $form->form_error_message_xml(
                sprintf('your reset password url is invalid. <a href="%s">try again</a>', $c->uri_for('forgot_password'))
            );
            $form->force_error_message(1);
            return;
        }
        my $auth_api = $c->registry(api => 'MemberAuth');
        $auth_api->update_auth(
            {
                member_id => $member->id,
                auth_type => 'password',
                password  => $form->param('password')
            },
        );
        my ($auth) = $auth_api->load_auth({ email => $form->param_value('email'), 'auth_type' => 'password' });
        $c->forward('/auth/authenticate', [ $member->email, $auth->auth_data, 'members_internal' ]);
        $c->res->redirect($c->uri_for('home'));
    }
    return ();
}

sub search :Local :Args(0) :FormConfig {
    my ($self, $c) = @_;

    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        $c->stash->{members} = $c->registry(api => 'Member')->search_members($form->params);
    }
    return ();
}

sub leave :Local :Args(0) :FormConfig {
    my ($self, $c) = @_;

    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        $c->stash->{template} = 'member/leave_confirm.tt';
        $form->action('/member/leave/commit');
    }
    return ();
}

sub leave_commit :Path('leave/commit') :Args(0) :FormConfig {
    my ($self, $c) = @_;

    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        $c->registry(api => 'Member')->soft_delete($c->user->id);
        $c->logout;
        $c->res->redirect($c->uri_for('/'));
        return;
    }

    # why would you get here?!
    $c->res->redirect($c->uri_for('/member/leave'));
    return ();
}

1;