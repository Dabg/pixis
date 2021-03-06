# $Id$

package Pixis::API::Event;
use Moose;
use Pixis::API::Base::DBIC;
use POSIX qw(strftime);
use namespace::clean -except => qw(meta);

with 'Pixis::API::Base::DBIC';

around create => sub {
    my ($next, $self, $args) = @_;

    my $schema = Pixis::Registry->get(schema => 'master');
    my $guard = $schema->txn_scope_guard();

    my $event = $next->($self, $args);
    Pixis::Registry->get(api => 'EventTrack')->create({
        event_id => $event->id,
        title    => 'Track 1'
    });
    my $event_date_api = Pixis::Registry->get(api => 'EventDate');
    my $cur = $event->start_on->clone;
    my $end = $event->end_on;
    while ($cur <= $end) {
        $event_date_api->create({
            event_id => $event->id,
            date => $cur->strftime('%Y/%m/%d'),
            created_on => \'NOW()',
        });
        $cur->add(days => 1);
    }
    $guard->commit;

    return $event;
};

around create_from_form => sub {
    my ($next, $self, $args) = @_;

    my $schema = Pixis::Registry->get(schema => 'master');
    my $guard = $schema->txn_scope_guard();

    my $event = $next->($self, $args);
    Pixis::Registry->get(api => 'EventTrack')->create({
        event_id => $event->id,
        title    => 'Track 1',
        created_on => DateTime->now,
    });
    my $event_date_api = Pixis::Registry->get(api => 'EventDate');
    my $cur = $event->start_on->clone;
    my $end = $event->end_on;
    while ($cur <= $end) {
        $event_date_api->create({
            event_id => $event->id,
            date => $cur->strftime('%Y/%m/%d'),
            created_on => \'NOW()',
        });
        $cur->add(days => 1);
    }

    $guard->commit;

    return $event;
};

sub add_session {
    my ($self, $args) = @_;

    my $schema = Pixis::Registry->get(schema => 'master');
    my $guard = $schema->txn_scope_guard();

    # If this event doesn't have a track, then create one.
    # The default track will just have a name Track 1
    my $track_api = Pixis::Registry->get(api => 'EventTrack');
    my $track;

    if (my $track_id = $args->{track_id}) {
        $track = $track_api->find($track_id);
    } else {
        $track = $track_api->load_or_create_default_track($args);
    }

    my %args = %$args;
    $args{track_id} = $track->id;

    $track_api->add_session(\%args);

    $guard->commit;
    return ();
}

sub load_tracks {
    my ($self, $args) = @_;
    return Pixis::Registry->get(api => 'EventTrack')->load_from_event($args);
}

sub load_sessions {
    my ($self, $args) = @_;

    my $track_api = Pixis::Registry->get(api => 'EventTrack');
    my $track;
    if (my $track_id = $args->{track_id}) {
        $track = $track_api->find($track_id);
    } else {
        $track = $track_api->load_or_create_default_track($args);
    }
    return $track_api->load_sessions({ track_id => $track->id });
}

sub load_sessions_from_date {
    my ($self, $args) = @_;

    my $event = $self->find($args->{event_id});
    my $date = $args->{date} || $event->start_on;

    return Pixis::Registry->get(api => 'EventSession')
        ->load_from_date({ event_id => $event->id, start_on => $date });
}

sub load_previous {
    my ($self, $args) = @_;

    my @ids = $self->resultset->search(
        {
            end_on => { '<=' => strftime('%Y-%m-%d', localtime) },
            start_on => { '>=' => strftime('%Y-%m-%d', localtime(time() - 86400 * 90)) }
        },
        select => [ 'id' ],
    );
    return $self->load_multi(map { $_->id } @ids);
}

sub load_coming {
    my ($self, $args) = @_;

    my @ids = $self->resultset->search(
        { 
            -and => [
                start_on => { '<=' => $args->{max} },
                start_on => { '>'  => strftime('%Y-%m-%d', localtime) },
            ]
        },
        {
            select => [ 'id' ]
        }
    );

    return $self->load_multi(map { $_->id } @ids);
}

sub load_tickets {
    my ($self, $args) = @_;

    my $schema = Pixis::Registry->get(schema => 'master');
    return $schema->resultset('EventTicket')->search(
        {
            event_id => $args->{event_id},
        },
        {
            rows => 1
        }
    )->single ? 1 : ();
}

sub is_registration_open {
    my ($self, $args) = @_;

    my $event = $self->find($args->{event_id});
    return () if (! $event);

    # Make sure there are tickets registered for this event
    my $count;

    $count = $self->load_tickets({ event_id => $args->{event_id} });
    if (defined $count && $count <= 0) {
        return ();
    }

    # check how many people have registered
    $count = $self->load_registered_count({ event_id => $args->{event_id} });
    if ($count >= $event->capacity) {
        return ();
    }

    my $now = DateTime->now(time_zone => 'local');
    return $event->is_registration_open &&
        $event->registration_start_on <= $now &&
        $event->registration_end_on >= $now
    ;
}

sub load_registered_count {
    my ($self, $args) = @_;

    my $event = $self->find($args->{event_id});
    return () if (! $event);

    my $schema = Pixis::Registry->get(schema => 'master');
    # XXX we need to cache this
    my $row = $schema->resultset('EventRegistration')->search(
        { event_id => $args->{event_id} },
        {
            select => [ 'count(*)' ],
            as     => [ 'count' ]
        }
    )->single;
    return $row->get_column('count');
}

sub get_registration_status {
    my ($self, $args) = @_;
    my $schema = Pixis::Registry->get(schema => 'master');
    # XXX we need to cache this
    my ($row) = $schema->resultset('EventRegistration')->search(
        {
            member_id => $args->{member_id},
            event_id  => $args->{event_id},
        },
        {
            rows => 1,
        }
    );

    return () unless $row;

    my $order = Pixis::Registry->get(api => 'Order')->find($row->order_id);
    if ($order) {
        if ($order->amount > 0 && ($order->is_pending_accept || $order->is_pending_credit_check || $order->is_init)) {
            return -1; # registered, but unpaid
        } elsif ($order->is_done) {
            return 1;
        }
    }
    return ();
}

sub is_registered {
    my ($self, $args) = @_;

    my $schema = Pixis::Registry->get(schema => 'master');
    # XXX we need to cache this
    my ($ok) = $schema->resultset('EventRegistration')->search(
        {
            member_id => $args->{member_id},
            event_id  => $args->{event_id},
        },
        {
            rows => 1,
        }
    );
    return $ok;
}

sub register {
    my ($self, $args) = @_;

    my $schema = Pixis::Registry->get(schema => 'master');
    my $order = $schema->txn_do( sub { 
        my ($self, $args, $schema) = @_;
        my $event  = $self->find($args->{event_id});
        my $ticket = $schema->resultset('EventTicket')->search(
            {
                id => $args->{ticket_id},
                event_id => $args->{event_id}
            }
        )->single;
        die "Ticket with id $args->{ticket_id} could not be found" unless $ticket;

        # If the ticket should be paid onsite, then we create an order,
        # but we mark it as such... and also, the registration is
        # considered to be complete
        my $pay_onsite = ($ticket->payment_type == 1);

        my $order_api = Pixis::Registry->get(api => 'Order');

        my %order_args = (
            member_id   => $args->{member_id}, # pixis member ID
            amount      => $ticket->price,
            description => sprintf('%s - %s', $event->title, $ticket->name),
            created_on  => \'NOW()',
        );
        if ($pay_onsite) {
            $order_args{status} = &Pixis::Schema::Master::Order::ST_DONE;
        }

        my $order = $order_api->create(\%order_args);

        my %registration_args = (
            member_id  => $args->{member_id},
            event_id   => $args->{event_id},
            order_id   => $order->id,
            created_on => \'NOW()',
        );
        if ($pay_onsite) {
            $registration_args{is_active} = 1;
        }
        my $registration = $schema->resultset('EventRegistration')->create(\%registration_args);

        return $order;
    }, $self, $args, $schema );
    die "Failed to register" if $@;

    return $order;
}

sub get_dates {
    my ($self, $args) = @_;

    my $schema = Pixis::Registry->get(schema => 'Master');
    my @dates = $schema->resultset('EventDate')->search(
        {
            event_id => $args->{event_id}
        },
        {
            order_by => 'date ASC'
        }
    );
    return wantarray ? @dates : [@dates];
}

__PACKAGE__->meta->make_immutable;

1;