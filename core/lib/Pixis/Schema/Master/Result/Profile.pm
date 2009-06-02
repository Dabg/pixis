package Pixis::Schema::Master::Result::Profile;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Pixis::Schema::Master::Result';

__PACKAGE__->load_components("PK::Auto", "UTF8Columns", "TimeStamp", "Core");
__PACKAGE__->table("pixis_profile");
__PACKAGE__->add_columns(
    id => {
        data_type => 'CHAR',
        is_nullable => 0,
        size => 10,
    },
    profile_type_id => {
        data_type => 'INTEGER',
        is_nullable => 0,
        size => 32,
    },
    member_id => {
        data_type => 'INTEGER',
        is_nullable => 0,
        size => 32,
    },
    display_name => {
        data_type => 'TEXT',
        is_nullable => 0,
    },
    bio => {
        data_type => 'TEXT',
        is_nullable => 1,
    },
    modified_on => {
        data_type => "TIMESTAMP",
        is_nullable => 0,
        set_on_create => 1,
        set_on_update => 1,
    },
    created_on => {
        data_type => "DATETIME",
        is_nullable => 0,
        set_on_create => 1,
    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(member => 'Pixis::Schema::Master::Result::Member' => 'member_id');
__PACKAGE__->utf8_columns(qw(display_name bio));
__PACKAGE__->belongs_to(profile_type => 'Pixis::Schema::Master::Result::ProfileType' => 'profile_type_id');

sub populate_initial_data {
    my ($self, $schema) = @_;
    $schema->populate(
        Profile => [
            [ qw(id member_id profile_type_id display_name bio created_on) ],
            [ qw(4649464900 1 1 管理者 システム管理者 0000-00-00) ],
        ],
    );
    return ();
}

1;
