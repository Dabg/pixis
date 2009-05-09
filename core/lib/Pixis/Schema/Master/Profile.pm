package Pixis::Schema::Master::Profile;
use strict;
use warnings;
use base qw(Pixis::Schema::Base::MySQL);

__PACKAGE__->load_components("PK::Auto", "UTF8Columns", "InflateColumn::DateTime", "Core");
__PACKAGE__->table("pixis_profile");
__PACKAGE__->add_columns(
    id => {
        data_type => 'INTEGER',
        is_auto_increment => 1,
        is_nullable => 0,
        size => 32,
    },
    member_id => {
        data_type => 'INTEGER',
        is_nullable => 0,
        size => 32,
    },
    bio => {
        data_type => 'TEXT',
        is_nullable => 1,
    }
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(member => 'Pixis::Schema::Master::Member' => 'member_id');

1;
