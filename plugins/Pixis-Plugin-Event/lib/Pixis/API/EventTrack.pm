
package Pixis::API::EventTrack;
use Moose;
use Pixis::API::Base::DBIC;
use namespace::clean -except => qw(meta);

with 'Pixis::API::Base::DBIC';

sub load_or_create_default_track {
    my ($self, $args) = @_;

    my $schema = Pixis::Registry->get(schema => 'master');
    my $guard = $schema->txn_scope_guard();

    my $rs = $self->resultset;
    my $track = $rs->search(
        { event_id => $args->{event_id} },
        { select => [ qw(id) ] }
    )->single;
    if (! $track) {
        $track = $rs->create( {
            {
                event_id => $args->{event_id},
                title    => 'Track 1'
            }
        } );
    }
    $guard->commit;

    return $track;
}

sub load_from_event {
    my ($self, $event_id) = @_;

    my @tracks = 
        map { $_->id }
        $self->resultset->search(
            { event_id => $event_id },
            { select => [ qw(id) ] }
        )
    ;

    return $self->load_multi(@tracks);
}

__PACKAGE__->meta->make_immutable;

1;
