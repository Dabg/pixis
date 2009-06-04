package Pixis::Schema::Master::Result::MemberToProfile;
use Moose;
use DateTime;
use namespace::clean -except => qw(meta);

extends 'Pixis::Schema::Master::Result';

__PACKAGE__->load_components(qw(TimeStamp Core));
__PACKAGE__->table("pixis_member_to_profile");
__PACKAGE__->add_columns(
    member_id => {
        data_type => 'INTEGER',
        is_nullable => 0,
        size => 32,
    },
    profile_id => {
        data_type => 'CHAR',
        is_nullable => 0,
        size => 10,
    },
    moniker => {
        data_type => "VARCHAR",
        is_nullable => 0,
        size => 256
    },
    created_on => {
        data_type => "DATETIME",
        is_nullable => 0,
        set_on_create => 1,
    },
);
__PACKAGE__->set_primary_key('member_id', 'profile_id');
__PACKAGE__->add_unique_constraint(['profile_id']);

sub populate_initial_data {
    my ($self, $schema) = @_;
=pod
    $schema->populate(
        ProfileType => [
            [qw(name)],
            ['public'],
            ['private'],
        ],
    );
    return;
=cut
}

1;
