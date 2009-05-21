
package Pixis::API::EventSession;
use Moose;
use namespace::clean -except => qw(meta);

with 'Pixis::API::Base::DBIC';

sub _build_resultset_constraints {
    return +{ is_accepted => 1 };
}

before create => sub {
    my ($self, $args) = @_;

    my $ok = $self->check_overlap( {
        event_id => $args->{event_id},
        track_id => $args->{track_id},
        start_on => $args->{start_on},
        end_on   => $args->{end_on},
    });
    if (! $ok) {
        die "Selected timeslot conflicts with another session";
    }
};

sub check_overlap {
    my ($self, $args) = @_;

    # Make sure that there are no overlapping sessions
    my $start_on = $args->{start_on};
    my $end_on = $args->{end_on};

    return $self->resultset->search(
        {   
            event_id => $args->{event_id},
            track_id => $args->{track_id},
            -or => [
                start_on => { -between => [ $start_on, $end_on ] },
                end_on   => { -between => [ $start_on, $end_on ] },
            ]
        }
    )->single ? 0 : 1;
}

sub load_from_track {
    my ($self, $args) = @_;

    my $schema = Pixis::Registry->get(schema => 'master');
    my %where  = (
        event_id => $args->{event_id},
        track_id => $args->{track_id},
    );
    if ($args->{date}) {
        # XXX - Try as I might, I couldn't generate the proper script
        # from DBIx::Class and/or SQL::Abstract
        $where{start_on} = \sprintf(
            "BETWEEN %s AND DATE_ADD(%s, INTERVAL 1 DAY)",
            $schema->storage->dbh->quote($args->{date}),
            $schema->storage->dbh->quote($args->{date}),
        )
    }

    my @ids = map { $_->id } $self->resultset->search(
        \%where,
        {
            select => [ qw(id) ]
        },
    );

    return $self->load_multi(@ids);
}

sub load_from_date {
    my ($self, $args) = @_;

    my @ids = map { $_->id } $self->resultset->search(
        {
            event_id => $args->{event_id},
            start_on => { -between => [ $args->{start_on}, $args->{start_on}->clone->add(days => 1) ] },
        },
        {
            select => [qw(id)],
            order_by => [ 'start_on' ],
        }
    );

    return $self->load_multi(@ids);
}

sub load_unaccepted {
    my ($self, $args) = @_;

    my @ids = map { $_->id } $self->resultset->search(
        {
            event_id => $args->{event_id},
            is_accepted => 0,
        },
        {
            select => [ qw(id) ]
        }
    );

    return $self->load_multi(@ids);
}

__PACKAGE__->meta->make_immutable;

1;