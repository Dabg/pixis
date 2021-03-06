
package Pixis::Schema::Master::Result::ProfileUniqueId;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Pixis::Schema::Master::Result';

__PACKAGE__->load_components(qw(Core));
__PACKAGE__->table('pixis_profile_unique_id');
__PACKAGE__->add_columns(
    value => {
        data_type => "CHAR",
        is_nullable => 0,
        size => 10,
    },
    taken_on => {
        data_type => "DATETIME",
        is_nullable => 1
    }
);

__PACKAGE__->set_primary_key('value');

sub populate_initial_data {
    my ($self, $schema) = @_;

    $self->create_unique_keys($schema, 
        $ENV{PIXIS_ORDER_UNIQUE_ID_COUNT} || 100);
    return ();
}

sub create_unique_keys {
    my ($self, $schema, $howmany) = @_;

    $howmany ||= 1_000;
    $schema->populate(
        ProfileUniqueId => [
            [ qw(value) ],
            map { [ $self->create_unique_key(10) ] }
                1..$howmany
        ],
    );
    return ();
}

sub create_unique_key {
    my $self = shift;
    my $count = shift || 10;

    my @constituents = sort { rand > 0.5 } (0..9, 0..9, 0..9);

    return join('',
        map { $constituents[rand @constituents] } 1..$count);
}

1;
