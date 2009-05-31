
package Pixis::Schema::Master::Result::MemberActivity;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Pixis::Schema::Master::Result';

__PACKAGE__->load_components("PK::Auto", "TimeStamp", "Core");
__PACKAGE__->table("pixis_member_actiity");
__PACKAGE__->add_columns(
    "id" => {
        data_type => "INTEGER",
        is_auto_increment => 1,
        is_nullable => 0,
        size => 32,
    },
    member_id => {
        data_type => "INTEGER",
        is_nullable => 0,
        size => 32,
    },
    activity_id => {
        data_type => "INTEGER",
        is_nullable => 0,
        size => 32,
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
__PACKAGE__->set_primary_key("id");

1;