package Pixis::Schema::Master::Result::Profile;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Pixis::Schema::Master::Result';

__PACKAGE__->load_components("PK::Auto", "UTF8Columns", "InflateColumn::DateTime", "Core");
__PACKAGE__->table("pixis_profile");
__PACKAGE__->add_columns(
    id => {
        data_type => 'CHAR',
        is_nullable => 0,
        size => 10,
    },
    name => {
        data_type => "VARCHAR",
        is_nullable => 0,
        size => 256
    },
    member_id => {
        data_type => 'INTEGER',
        is_nullable => 0,
        size => 32,
    },
    bio => {
        data_type => 'TEXT',
        is_nullable => 1,
    },
    modified_on => {
        data_type => "TIMESTAMP",
        is_nullable => 0,
        default_value => \'NOW()',
    },
    created_on => {
        data_type => "DATETIME",
        is_nullable => 0,
    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(member => 'Pixis::Schema::Master::Result::Member' => 'member_id');
__PACKAGE__->utf8_columns(qw(bio name));

1;
