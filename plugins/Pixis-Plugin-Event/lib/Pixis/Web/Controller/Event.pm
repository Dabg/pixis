
package Pixis::Web::Controller::Event;
use Moose;
use namespace::clean -except => qw(meta);
use utf8;
use Encode();
use DateTime::Format::Strptime;

BEGIN { extends 'Catalyst::Controller::HTML::FormFu' }

sub index :Index :Args(0) {
    my ($self, $c) = @_;

    my $event_api = $c->registry(api => 'Event');
    $c->stash->{previous_events} = $event_api->load_previous();
    $c->stash->{events} = $event_api->load_coming(
        { max => DateTime->now(time_zone => 'local')->add(years => 1) });
    return ();
}

sub create :Local :FormConfig :PixisPriv('admin') {
    my ($self, $c) = @_;

    $c->forward('/auth/assert_roles', ['admin']);
    my $form = $c->stash->{form};

    if ($form->submitted_and_valid) {
        # XXX Make a subsession + confirm later
        $form->add_valid(created_on => \'NOW()');
        $form->param('end_on')->add(days => 1)->subtract(seconds => 1);
        $form->param('registration_end_on')->add(days => 1)->subtract(seconds => 1);
        my $event = eval {
            $c->registry(api => 'Event')->create_from_form($c->stash->{form});
        };
        if ($@) {
            if ($@ =~ /Duplicate entry/) {
                $form->form_error_message("Event ID " . $form->param('id') . " already exists");
                $form->force_error_message(1);
            } else {
                $c->res->body("Creation failed: $@");
            }
            return;
        }
        return $c->res->redirect($c->uri_for('/event/' . $event->id));
    }
    return ();
}

sub load_event :Chained :PathPart('event') :CaptureArgs(1) {
    my ($self, $c, $id) = @_;

    $c->stash->{event} = 
        eval { $c->registry(api => 'Event')->find($id) };
    if ($@) {
        $c->log->error("Error at load_event: $@");
    }
    if (! $c->stash->{event}) {
        Pixis::Web::Exception->throw(status => 404, message => "Requrested event $id was not found");
    }

    $c->stash->{tracks} = 
        $c->registry(api => 'Event')->load_tracks($id);
    return ();
}

sub view :Chained('load_event') :PathPart('') :Args(0) {
    return ();
}

sub edit :Chained('load_event') :PathPart('edit') :Args(0) :FormConfig {
    my ($self, $c) = @_;

    $c->forward('/auth/assert_roles', ['admin']) or return;
    my $event = $c->stash->{event};
    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        $form->model->update($event);
        $c->res->redirect($c->uri_for('/event', $event->id));
        return;
    } else {
        $form->model->default_values($event);

        $c->stash->{f_ticket} = $self->form;
        $c->stash->{f_ticket}->load_config_file('event/ticket/create.yml');
        $c->stash->{f_ticket}->action($c->uri_for('/event', $event->id, 'ticket', 'create'));

        my @dates;
        foreach my $date ($c->registry(api => 'Event')->get_dates({ event_id => $event->id })) {
            my $f = $self->form();
            $f->load_config_file('event/date.yml');
            $f->action($c->uri_for('/event', $event->id, 'date', $date->date));
            $f->model->default_values($date);
            push @dates, [ $date->date, $f ];
        }
        $c->stash->{dates} = \@dates;
    }
    return ();
}

sub attendees :Chained('load_event') :Args(0) {
    return ();
}

sub load_ticket :Chained('load_event') :CaptureArgs(1) :PathPart('ticket') {
    my ($self, $c, $ticket) = @_;

    $c->stash->{ticket} = $c->registry(api => 'EventTicket')->find($ticket);
    return ();
}

sub register :Chained('load_event') :Args(0) :FormConfig {
    my ($self, $c) = @_;

    $c->forward('/auth/assert_logged_in');
    return ();
}

sub register_confirm :Chained('load_ticket') :PathPart('register/confirm') :Args(0) :FormConfig {
    my ($self, $c) = @_;

    $c->forward('/auth/assert_logged_in') or return;

    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        my $event = $c->stash->{event};
        my $api = $c->registry(api => 'Event');
        if (! $api->is_registration_open({ event_id => $event->id }) ) {
            # XXX Proper error handling
            $c->error("stop");
            $c->detach('');
        }

        if ($api->is_registered({ event_id => $event->id, member_id => $c->user->id })) {
            Pixis::Web::Exception->throw(safe_message => 1, message => "You are already registered for this event!");
        }
        my $order = $api->register({
            event_id => $c->stash->{event}->id,
            member_id => $c->user->id,
            ticket_id => $c->stash->{ticket}->id,
        });

        $c->res->redirect($c->uri_for('/event', $event->id, 'ticket', $c->stash->{ticket}->id, 'registered', $order->id));
        return;
    }
    return ();
}

sub registered :Chained('load_ticket') :Args(1) {
    my ($self, $c, $order_id) = @_;

    $c->forward('/auth/assert_logged_in') or return;
    # Now that I'm registered, prompt the user to pay by paypal or by
    # bank transfer

    my $registration = $c->registry(api => 'EventRegistration')->load_from_order(
        {
            event_id  => $c->stash->{event}->id,
            member_id => $c->user->id,
            order_id  => $order_id
        }
    );

    if (! $registration) {
        Pixis::Web::Exception->throw(message => "Could not find registration that matches order id $order_id");
    }

    my $order = $c->registry(api => 'Order')->find($order_id);
    $c->stash->{order} = $order;

    if ($order->amount <= 0) {
        $c->forward('send_confirmation');
    }
    return ();
}

my $fmt = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d', time_zone => 'local');
sub date :Chained('load_event')
         :Args(1)
         :PathPart('date')
{
    my ($self, $c, $date) = @_;

    if ($c->req->method eq 'POST') {
        $c->forward('/auth/assert_roles', [ 'admin' ]) or return;
    }

    $c->stash->{date} = $fmt->parse_datetime($date);
    my $d = Pixis::Registry->get(api => 'EventDate')->load_from_event_date({ event_id => $c->stash->{event}->id, date => $date });
    $d->start_on =~ /^(\d+)/;
    $c->stash->{start_hour} = int( $1 );
    $d->end_on =~ /^(\d+)/;
    $c->stash->{end_hour} = int( $1 );
    return ();
}

sub sessions_default
    :Chained('load_event')
    :PathPart('sessions')
    :Args
{
    my ($self, $c) = @_;

    my $dt = $c->stash->{event}->start_on;
    $c->res->redirect(
        $c->uri_for('/event', $c->stash->{event}->id, 'sessions', $dt->strftime('%Y-%m-%d')));
}

sub sessions
    :Chained('load_event')
    :Args(1)
{
    my ($self, $c, $date) = @_;

    # Make sure $date is parseable 
    my $parser = DateTime::Format::Strptime->new(
        pattern => '%Y-%m-%d',
        time_zone => 'local',
    );
    my $dt = eval { $parser->parse_datetime($date) };
    if ($@ || !$dt) {
        Pixis::Web::Exception::FileNotFound->throw();
    }

    my $event = $c->stash->{event};
    if ($dt < $event->start_on || $dt > $event->end_on) {
        Pixis::Web::Exception::FileNotFound->throw();
    }

    $c->stash->{date} = $dt;

    my @tracks = $c->registry(api => 'EventTrack')->load_from_event($event->id);
    $c->stash->{tracks} = \@tracks;

    my $session_api = $c->registry(api => 'EventSession');
    my %sessions;
    foreach my $track (@tracks) {
        $sessions{$track->id} = $session_api->load_from_track({
            event_id => $event->id,
            track_id => $track->id,
            date     => $date
        });
    }
    $c->stash->{sessions} = \%sessions;

}

# XXX this sucks. later!
sub send_confirmation : Private {
    my ($self, $c) = @_;
    my $body = $c->view('TT')->render($c, 'event/registration_confirmation.tt');

    $c->controller('Email')->send($c, {
        header => {
            To      => $c->user->email,
            From    => 'no-reply@perlassociation.org',
            Subject => "イベント登録確認",
        },
        body    => $body
    });
    return ();
}

sub done :Local {
    my ($self, $c, $subsession) =  @_;
    my $id = delete $c->session->{signup}->{$subsession};
    return ();
}

sub cfp
    :Chained('/event/load_event')
    :Args
    :FormConfig
{
    my ($self, $c) = @_;

    return unless $c->forward('/auth/assert_logged_in');

    if (! $c->stash->{event}->is_cfp_open) {
        $c->res->redirect( $c->uri_for('/event', $c->stash->{event}->id, 'cfp', 'unavailable') );
        return;
    }

    my $form = $c->stash->{form};

    if ($form->submitted_and_valid) {
        my $event = $c->stash->{event};

        # This session is created, but with the accept flag being off
        $c->registry(api => 'EventSession')->create({
            owner_id   => $c->user->id,
            event_id    => $c->stash->{event}->id,
            presenter   => $c->user->nickname,
            title       => $form->param('title'),
            description => $form->param('description'),
            is_accepted => 0,
            created_on  => \'NOW()',
        });
        $c->res->redirect($c->uri_for('/event', $event->id, 'cfp', 'submitted'));
    }
    return ();
}

sub cfp_submitted
    :Chained('/event/load_event')
    :PathPart('cfp/submitted')
    :Args
{
    return ();
}

sub cfp_unavailable
    :Chained('/event/load_event')
    :PathPart('cfp/unavailable')
    :Args
{
    return ();
}

1;