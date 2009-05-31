
package Pixis::Schema::Master::Result::ActivityGithub;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Pixis::Schema::Master::Result';

__PACKAGE__->load_components("PK::Auto", "UTF8Columns", "TimeStamp", "Core");
__PACKAGE__->table("pixis_activity_github");
__PACKAGE__->add_columns(
    "id" => {
        data_type => "INTEGER",
        is_auto_increment => 1,
        is_nullable => 0,
        size => 32,
    },
    entry_id => {
        data_type => "VARCHAR",
        is_nullable => 0,
        size => 1024,
    },
    link => {
        data_type => "TEXT",
        is_nullable => 0,
    },
    title => {
        data_type => "VARCHAR",
        is_nullable => 0,
        size => 1024,
        is_nullable => 0,
    },
    content => {
        data_type => "TEXT",
        is_nullable => 0,
    },
    activity_on => {
        data_type => "DATETIME",
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
__PACKAGE__->utf8_columns(qw(title content));

__PACKAGE__->set_primary_key("id");

1;