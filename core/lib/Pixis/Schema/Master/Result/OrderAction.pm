
package Pixis::Schema::Master::Result::OrderAction;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Pixis::Schema::Master::Result';

__PACKAGE__->load_components("PK::Auto", "TimeStamp", "Core");
__PACKAGE__->table("pixis_order_action");
__PACKAGE__->add_columns(
    "id" => {
        data_type => "INTEGER",
        is_auto_increment => 1,
        is_nullable => 0,
        size => 8,
    },
    order_id => {
        data_type => "CHAR",
        is_nullable => 0,
        size => 12,
    },
    message => {
        data_type => "TEXT",
        is_nullable => 0
    },
    created_on => {
        data_type => "TIMESTAMP",
        is_nullable => 0,
        set_on_create => 1,
    },
);

__PACKAGE__->set_primary_key("id");

1;
