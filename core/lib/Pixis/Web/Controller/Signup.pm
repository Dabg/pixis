
package Pixis::Web::Controller::Signup;
use Moose;
use MooseX::AttributeHelpers;
use utf8;
use namespace::clean -except => qw(meta);

# README
#
# steps: the sequence of actions to handle signup state

BEGIN {
    extends 'Pixis::Web::ControllerBase';
    with 'Pixis::Web::ControllerBase::WithSubsession';
}

has '+default_auth' => ( default => 0 );

has steps => (
    metaclass => 'Collection::Array',
    is => 'rw',
    isa => 'ArrayRef[Str]',
    lazy_build => 1,
    required => 1,
    provides => {
        push => 'add_step'
    }
);

has activation_mail_header => (
    metaclass => 'Collection::Hash',
    is => 'rw',
    isa => 'HashRef',
    lazy_build => 1,
    required => 1,
);

sub _build_steps {
    return ['start', 'experience', 'commit', 'send_activate', 'activate' ]
}

sub _build_activation_mail_header {
    return {
        From => 'no-reply@pixis.local',
        Subject => "登録アクティベーションメール",
    }
}

sub index :Index :Args(0) :Path {
    my ($self, $c) = @_;
    $self->next_step($c);
    return ();
}

# Ask things like name, and email address
sub start :Local :Args(1)
{
    my ($self, $c, $subsession) = @_;

    my $form = $self->form($c);
    $c->stash->{form} = $form;
    if ($form->submitted_and_valid) {
        # check if this email has already been taken
        my $member_api = $c->registry(api => 'Member');
        {
            local $member_api->{resultset_constraints} = {};
            if ( $member_api->load_from_email($form->param('email')) ) {
                $form->form_error_message("使用されたメールアドレスはすでに登録されています");
                $form->force_error_message(1);
                return;
            }
        }

        my $params = $form->params;
        delete $params->{password_check}; # no need to include it here
        $params->{current_step} = 'start';
        $self->set_subsession($c, $subsession, $params);
        return $self->next_step($c, $subsession);
    }
    return ();
}

sub next_step :Private {
    my ($self, $c, $subsession) = @_;

    my $p;
    if ($subsession) {
        $p = $self->get_subsession($c, $subsession);
    } else {
        $p = {};
        $subsession = $self->new_subsession($c, $p);
    }

    my $step;

    my $path = $c->action->name;
    # find the step with the same name
    my $steps = $self->steps;
    foreach my $i (0..$#{$steps}) {
        if ($steps->[$i] eq $path) {
            if ($i == $#{$steps}) {
                $step = 'done';
            } else {
               $step = $steps->[$i + 1];
            }
        }
    }

    if (! $step) {
        $step = $steps->[0];
    }
    $self->set_subsession($c, $subsession, $p);

    my $uri = $c->uri_for($step, $subsession);
    $c->log->debug("Next step is forwading to $uri") if $c->debug;
    $c->res->redirect( $uri );
    $c->finalize();
    return ();
}

# Ask things like coderepos/github accounts
sub experience
    :Local
    :Args(1)
{
    my ($self, $c, $subsession) = @_;

    my $form = $self->form($c);
    $c->stash->{form} = $form;
    if ($form->submitted_and_valid) {
        my $p = $self->get_subsession($c, $subsession);
        my $params = Catalyst::Utils::merge_hashes($p, scalar $form->params);
        $self->set_subsession($c, $subsession, $params);
        return $c->forward('next_step', [$subsession]); 
    }
    return ();
}

# All done, save
sub commit
    :Local
    :Args(1)
{
    my ($self, $c, $subsession) = @_;

    my $form = $self->form($c);
    $c->stash->{form} = $form;
    if ($form->submitted_and_valid) {
        my $p = $self->get_subsession($c, $subsession);
        # submit element will exist... remove
        delete $p->{submit};
        delete $p->{current_step};
        $p->{activation_token} = $c->generate_session_id;
        my $member = $c->registry(api => 'Member')->create($p);
        if ($member) {
            $p->{current_step} = 'commit';
            $p->{activation_token} = $member->activation_token;
            $self->set_subsession($c, $subsession, $p);
            return $c->forward('next_step', [$subsession]);
        } 
    }
    $c->stash->{confirm} = $self->get_subsession($c, $subsession);
    return ();
}

sub activate
    :Local
    :Args(0)
{
    my ($self, $c) = @_;

    my $form = $self->form($c);
    $c->stash->{form} = $form;
    if ($form->submitted_and_valid) {
        if ($c->registry(api => 'Member')->activate({
                token => $form->param('token'),
                email => $form->param('email')
        })) {
            # we've activated. now start a new subsession, so we can forward to
            # whatever next step 
            my $subsession = $self->new_subsession($c, {current_step => 'activate'});

            my $member = $c->registry(api => 'Member')->load_from_email($form->param_value('email'));
            my ($auth) = $c->registry(api => 'MemberAuth')->load_auth({ email => $form->param_value('email'), 'auth_type' => 'password' });
            $c->forward('/auth/authenticate', [ $member->email, $auth->auth_data, 'members_internal' ]);
            
            return $c->forward('next_step', [$subsession]);
        }
        $form->form_error_message("指定されたユーザーは存在しませんでした");
        $form->force_error_message(1);
    }
    return ();
}

sub send_activate :Local :Args(1) {
    my ($self, $c, $subsession) = @_;

    my $p = $self->get_subsession($c, $subsession);

    $c->stash->{ activation_token } = $p->{activation_token};
    $c->stash->{ email } = $p->{email};

    my $body = $c->view('TT')->render($c, 'signup/activation_email.tt');

    $c->controller('Email')->send($c, {
        header => {
            %{$self->activation_mail_header},
            To   => $p->{email},
        },
        body => $body
    });

    $c->res->redirect($c->uri_for('activate'));
    return ();
}

sub done :Local {
    my ($self, $c, $subsession) =  @_;
    $c->res->redirect($c->uri_for('/member/home'));
    return ();
}

1;
