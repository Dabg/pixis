
package Pixis::Web::Controller::Event::Session;
use Moose;
use namespace::clean -except => qw(meta);

BEGIN { extends 'Catalyst::Controller::HTML::FormFu' }
use DateTime::Format::Duration;

sub load_session :Chained('/event/load_event') 
               :PathPart('session')
               :CaptureArgs(1)
{
    my ($self, $c, $session_id) = @_;

    # hmm, may need to check session.event_id = event.id
    my $session = $c->registry(api => 'EventSession')->find($session_id);
    if (! $session->is_accepted ) {
        if ($c->user->id ne $session->owner_id && ! $c->check_user_roles('admin')) {
            Pixis::Web::Exception::FileNotFound->throw();
        }
    }
    $c->stash->{session} = $session;
    return ();
}

sub add :Chained('/event/track/load_track')
        :PathPart('session/add')
        :Args(0)
        :FormConfig
{
    my ($self, $c) = @_;

    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        $form->add_valid(event_id => $c->stash->{event}->id);
        $form->add_valid(track_id      => $c->stash->{track}->id);
        $form->add_valid(end_on        => $form->param('start_on') + DateTime::Duration->new(minutes => $form->param('duration')) );
        $form->add_valid(created_on    => \'NOW()');
        eval {
            $c->registry(api => 'EventSession')->create_from_form($form);
        };
        if (my $e = $@) {
            if ($e =~ /Selected timeslot conflicts with another session/) {
                $form->form_error_message(
                    $c->localize("Selected timeslot conflicts with another session") );
            } else {
                $form->form_error_message($e);
            }
            $form->force_error_message(1);
        } else {
            $c->res->redirect(
                $c->uri_for('/event', $c->stash->{event}->id, 'track', $c->stash->{track}->id));
        }
    }
    return ();
}

my $dur_format = DateTime::Format::Duration->new(
    pattern => '%s'
);
sub list :Chained('/event/track/load_track')
        :PathPart('session/list')
        :Args(0)
{
    my ($self, $c) = @_;
    $c->stash->{json} = [ map { 
        my $start_on = $_->start_on;
        my $end_on   = $_->end_on;
        {
            id => $_->id,
            title => $_->title,
#            start_on => $start_on->strftime('%Y-%m-%d %H:%M'),
            end_on   => $end_on->strftime('%Y-%m-%d %H:%M'),
            start_on => $dur_format->format_duration($start_on - $start_on->clone->truncate(to => 'day')),
            duration => $dur_format->format_duration($_->end_on - $_->start_on),
        }
    }
        $c->registry(api => 'EventSession')->load_from_track( {
            event_id => $c->stash->{event}->id,
            track_id      => $c->stash->{track}->id,
        } )
    ] ;
    $c->forward('View::JSON');
    return ();
}

sub view :Chained('load_session')
         :PathPart('')
         :Args(0)
{
    return ();
}

sub edit 
    :Chained('load_session')
    :Args
    :FormConfig
{
    my ($self, $c) = @_;

    return unless $c->forward('/auth/assert_logged_in');

    if (! $c->forward('/auth/assert_roles', [ 'admin' ] ) ||
            $c->user->id ne $c->stash->{session}->owner_id
    ) {
        return $c->detach('/auth/fail');
    }

    my $form = $c->stash->{form};


    my @tracks = $c->registry(api => 'EventTrack')->load_from_event(
        $c->stash->{event}->id);
    my $track = $form->get_all_element({ name => 'track_id' });
    $track->options([
        map { [ $_->id, $_->title ] } @tracks
    ]);

    if ($form->submitted_and_valid) {
        $c->registry(api => 'EventSession')->update_from_form(
            $form, $c->stash->{session}
        );
        $c->res->redirect(
            $c->uri_for('/event', $c->stash->{event}->id, 'session', $c->stash->{session}->id, 'updated' ));
    } else {
        $form->model->default_values( $c->stash->{session} );
    }
    return ();
}

sub accept
    :Chained('load_session')
    :Args
{
    my ($self, $c) = @_;

    my $session = $c->stash->{session};
    $c->registry(api => 'EventSession')->update( {
        id => $session->id,
        is_accepted => $session->is_accepted ? 0 : 1,
    });
    
    $c->res->redirect(
        $c->uri_for('/event', $c->stash->{event}->id, 'session', $session->id, 'updated' ));
    return ();
}

sub updated
    :Chained('load_session')
    :Args
{
    return ();
}

sub list
    :Chained('/event/load_event')
    :PathPart('session/list')
    :Args
{
    my ($self, $c) = @_;

    if ($c->check_user_roles('admin')) {
        $c->stash->{unaccepted} = $c->registry(api => 'EventSession')->load_unaccepted({
            event_id => $c->stash->{event}->id,
        });
    }
    return ();
}

1;
