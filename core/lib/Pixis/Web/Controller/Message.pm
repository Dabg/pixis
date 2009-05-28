package Pixis::Web::Controller::Message;
use Moose;
use namespace::clean -except => qw(meta);
use utf8;

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

sub create :Local :Path('create') :Args(0) :FormConfig('message/edit') {
    my ( $self, $c ) = @_;

    my $form = $c->stash->{form};
for (@{$form->get_all_elements}) {
    $c->log->debug(ref $_ );
}
    my $select = $form->get_elemente({type => 'Select', name => 'from_profile_id'});
    $c->log->_dump($form->get_element({type => 'Text', name => 'subject'}));
#    $c->registry(api => 'Profile')->load_to_profile_select(
#        {
#            member_id => $c->user->id,
#            select => $select,
#        }
#    );
    $form->process;
    if ($form->submitted_and_valid) {
        my $to;
        if ($form->param_value('to_profile_id')) {
            $to = $c->registry(api => 'Profile')
                ->find($form->param_value('to_profile_id'))
        }
        $to or return $c->res->redirect( $c->uri_for('/member/home') );
        my $message = $c->registry(api => 'Message')->send(
            {
                from => $c->user,
                to => $to,
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
    my $message = $c->registry(api => 'Message')->find($id);
    if (
        (!$message) || (
            $message->from_member_id != $c->user->id &&
            $message->to_member_id != $c->user->id
        )
    ) {
        return $c->res->redirect($c->uri_for('/message'));
    }
    $c->stash->{message} = $message;
    return;
}

sub view :Chained('load_message') :PathPart('') :Args(0) {
    my ( $self, $c ) = @_;
    return;
}

1;
