
package Pixis::Schema::Master::Result::ProfilePhoto;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Pixis::Schema::Master::Result';

__PACKAGE__->load_components("TimeStamp", "Core");
__PACKAGE__->table("pixis_profile_photo");
__PACKAGE__->add_columns(
    "profile_id" => {
        data_type => "CHAR",
        is_nullable => 0,
        size => 10,
    },
    content_type => {
        data_type => "CHAR",
        is_nullable => 0,
        size => 16,
    },
    data => {
        data_type => "BLOB",
        is_nullable => 0,
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
__PACKAGE__->set_primary_key("profile_id");

1;