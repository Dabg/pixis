package Pixis::Schema::Master::Result::Message;
use strict;
use warnings;
use base qw(Pixis::Schema::Base::MySQL);

__PACKAGE__->load_components("PK::Auto", "UTF8Columns", "InflateColumn::DateTime", "Core");
__PACKAGE__->table("pixis_message");
__PACKAGE__->add_columns(
    id => {
        data_type => 'CHAR',
        is_nullable => 0,
        size => 40,
    },
    from_member_id => {
        data_type => 'INTEGER',
        is_nullable => 0,
        size => 32,
    },
    to_member_id => {
        data_type => 'INTEGER',
        is_nullable => 0,
        size => 32,
    },
    subject => {
        data_type => 'VARCHAR',
        is_nullable => 0,
        size => 256,
    },
    body => {
        data_type => 'TEXT',
        is_nullable => 1,
    },
    created_on => {
        data_type => "DATETIME",
        is_nullable => 0,
    }
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->utf8_columns('subject','body');

1;
