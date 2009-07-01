package Pixis::Web::Controller::Message;
use Moose;
use namespace::clean -except => qw(meta);
use utf8;
use YAML::Syck ();
use Data::Visitor::Callback;

BEGIN {
    extends qw(Pixis::Web::ControllerBase);
}
with 'Pixis::Web::ControllerBase::WithSubsession';

has '+default_auth' => (default => 1);

sub tag
    :Local
    :Path('tag')
    :Args(1)
{
    my ($self, $c, $tag) = @_;
    # By default, show messages received
    my @messages = eval {
        $c->registry(api => 'Message')->load_from_member(
            { 
                member_id => $c->user->id,
                tag => $tag,
            }
        )
    };
    if ($@) {
        $c->detach('/default');
        return;
    }
    
    $c->stash(
        messages => \@messages,
        mailbox  => ucfirst($tag),
        template => 'message/index.tt', 
        form => $self->form($c, 'message/search')
    );
    return;
    
}

sub index
    :Local
    :Path('')
    :Args(0)
{
    my ( $self, $c ) = @_;
    $c->res->redirect($c->uri_for('tag/inbox'));
    return;
}

sub search
    :Local
    :Args(0)
{
    my ($self, $c) = @_;

    my @messages = $c->registry(api => 'Message')
         ->load_from_query(
             member_id => $c->user->id, 
             query => $c->stash->{form}->param_value('q'),
         )
    ;
    $c->stash(
        messages => \@messages,
        form => $self->form($c, 'message/search')
    );
    return;
}

sub create
    :Local
    :Path('create')
    :Args(1)
{
    my ( $self, $c, $to_profile_id ) = @_;

    my $papi = $c->registry(api => 'Profile');
    my $recipient = $papi->find($to_profile_id);
    if (! $recipient) {
        $c->detach('/default');
        return;
    }

    my $member_id = $c->user->id;
    my $form = $self->form($c, {
        filename => 'message/edit',
        config_callback => {
            hash => sub { 
                return $self->_create_form_callback(
                    @_, 
                    {
                        member_id => $member_id, 
                        recipient => $recipient,
                    }
                ) 
            }
        }
     } );
    $c->stash->{form} = $form;

    if ($form->submitted_and_valid) {
        my $subsession = $self->new_subsession($c, {
            from    => $form->param_value('from_profile_id'),
            to      => $to_profile_id,
            subject => $form->param_value('subject'),
            body    => $form->param_value('body'),
        });
        return $c->res->redirect( $c->uri_for('/message/create/confirm', $subsession) ) if $subsession;
    }

    return;
}

sub create_confirm
    :Path('create/confirm')
    :Args(1)
{
    my ($self, $c, $subsession) = @_;

    my $hash = $self->get_subsession($c, $subsession);
    if (! $hash ) {
        $c->detach('/default');
        return ();
    }

    my $papi = $c->registry(api => 'Profile');
    $c->stash(
        subsession => $subsession,
        message    => {
            %$hash,
            from_profile => $papi->find($hash->{from}),
            to_profile => $papi->find($hash->{to}),
        }
    );
    return;
}

sub create_commit
    :Path('create/commit')
    :Args(1)
{
    my ($self, $c, $subsession) = @_;

    my $hash = $self->get_subsession($c, $subsession);
    if (! $hash ) {
        $c->detach('/default');
        return ();
    }

    my $message = $c->registry(api => 'Message')->send( $hash );
    $self->delete_subsession( $c, $subsession );

    return $c->res->redirect( $c->uri_for( 'create', 'done') );
}

sub create_done
    :Path('create/done')
{
}

sub load_message
    :Chained
    :PathPart('message')
    :CaptureArgs(1)
{
    my ( $self, $c, $id ) = @_;
    my $api = $c->registry(api => 'Message');
    my $message = $api->find($id);
    if (! $message ) {
        Pixis::Web::Exception::FileNotFound->throw();
    }
    $c->stash->{message} = $message;
    return;
}

sub view
    :Chained('load_message')
    :PathPart('')
    :Args(0)
{
    my ( $self, $c ) = @_;

    if (! $c->registry(api => 'Message')->is_viewable($c->stash->{message}, $c->user)) {
        Pixis::Web::Exception::FileNotFound->throw();
    }
    $c->registry(api => 'MessageRecipient')->set_read($c->stash->{message}, $c->user);
    return;
}

sub _create_form_callback {
    my ($self, $visitor, $value, $args) = @_;

    return $value unless $value->{name};
    if ( $value->{name} eq 'from_profile_id' ) {
        my $member_id = $args->{member_id};
        my @profiles = Pixis::Registry->get(api => 'Profile')->load_from_member( {
                member_id => $member_id
            } ) ;

        $value->{options} = [
        map { [ $_->id, $_->display_name, ] } @profiles
        ];
    }
    if ( $value->{name} eq 'to_profile_id' ) {
        my $recipient = $args->{recipient};
        $value->{options} = [
        [ $recipient->id, $recipient->display_name ]
        ];
    }
    return $value;
}

1;
