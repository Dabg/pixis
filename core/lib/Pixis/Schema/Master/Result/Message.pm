package Pixis::Schema::Master::Result::Message;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Pixis::Schema::Master::Result';

__PACKAGE__->load_components("PK::Auto", "UTF8Columns", "TimeStamp", "Core");
__PACKAGE__->table("pixis_message");
__PACKAGE__->add_columns(
    id => {
        data_type => 'CHAR',
        is_nullable => 0,
        size => 40,
    },
    from_profile_id => {
        data_type => 'CHAR',
        is_nullable => 0,
        size => 10,
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
    is_system_message => {
        # Is this message from the system? if so, all security checks are OFF!
        data_type => 'TINYINT',
        is_nullable => 0,
        default_value => 1,
    },
    created_on => {
        data_type => "DATETIME",
        is_nullable => 0,
        set_on_create => 1,
    }
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->utf8_columns('subject','body');
=pod
__PACKAGE__->belongs_to(
    'from_profile',
    'Pixis::Schema::Master::Result::Profile',
    'from_profile_id'
);
=cut
__PACKAGE__->has_many(
    'recipients',
    'Pixis::Schema::Master::Result::MessageRecipient',
    'message_id',
);

1;
