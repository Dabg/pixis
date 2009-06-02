package Pixis::Web::Controller::Message;
use Moose;
use namespace::clean -except => qw(meta);
use utf8;
use YAML::Syck ();
use Data::Visitor::Callback;

BEGIN { extends 'Catalyst::Controller::HTML::FormFu' };

sub auto :Private {
    my ( $self, $c ) = @_;
    $c->forward('/auth/assert_logged_in') or return;
    return 1;
}

sub index
    :Local
    :Path('')
    :Args(0)
    :FormConfig('message/search')
{
    my ( $self, $c ) = @_;

    # By default, show messages received
    my @messages = $c->registry(api => 'Message')
        ->load_sent_to_member({ member_id => $c->user->id })
    ;
    $c->stash->{messages} = \@messages;
    return;
}

sub sent
    :Local
    :Args(0)
    :FormConfig('message/search')
{
    my ( $self, $c ) = @_;
    my @messages = $c->registry(api => 'Message')
        ->load_sent_from_member({ member_id => $c->user->id })
    ;
    $c->stash(
        messages => \@messages,
        mailbox => 'SENT',
        template => 'message/index.tt', 
    );
    return;
}

sub search
    :Local
    :Args(0)
    :FormConfig
{
    my ($self, $c) = @_;

    my @messages = $c->registry(api => 'Message')
                 ->load_from_query(
                         member_id => $c->user->id, 
                         query => $c->stash->{form}->param_value('q'),
                     );
    $c->stash->{messages} = \@messages;
    return;
}

sub create
    :Local
    :Path('create')
    :Args(0)
    :FormMethod('load_form')
{
    my ( $self, $c ) = @_;

    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        my $papi = $c->registry(api => 'Profile');
        my $message = $c->registry(api => 'Message')->send(
            {
                from => $papi->find($form->param_value('from_profile_id')),
                to => $papi->find($form->param_value('to_profile_id')),
                subject => $form->param_value('subject'),
                body => $form->param_value('body'),
            }
        );
        return $c->res->redirect( $c->uri_for($message->id) );
    }
    return;
}

sub load_message :Chained :PathPart('message') :CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;
    my $api = $c->registry(api => 'Message');
    my $message = $api->find($id);
    if (! $message ) {
        Pixis::Web::Exception::FileNotFound->throw();
    }
    $c->stash->{message} = $message;
    return;
}

sub view :Chained('load_message') :PathPart('') :Args(0) {
    my ( $self, $c ) = @_;

    if (! $c->registry(api => 'Message')->is_viewable($c->stash->{message}, $c->user)) {
        Pixis::Web::Exception::FileNotFound->throw();
    }
    $c->registry(api => 'MessageRecipient')->set_read($c->stash->{message}, $c->user);
    return;
}

sub load_form {
    my ($self, $c) = @_;
    my $hash = YAML::Syck::LoadFile($c->path_to(qw(root forms message edit.yml)));
    my $v = Data::Visitor::Callback->new(
        hash => sub {
            my ( $visitor, $value ) = @_;

            return $value unless $value->{name};
            return $value unless $value->{name} eq 'from_profile_id';

            my @profiles = $c->registry(api => 'Profile')->load_from_member( {
                member_id => $c->user->id,
            } ) ;

            $value->{options} = [
                map { [
                    $_->id, 
                    $_->display_name,
#                    sprintf( '%s (%s)', $_->display_name, $_->profile_type->name )
                ] } @profiles
            ];
            return $value;
        }
    );
    $v->visit($hash);
    return $hash;
}

1;
