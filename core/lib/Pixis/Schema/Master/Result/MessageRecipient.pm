package Pixis::Schema::Master::Result::MessageRecipient;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Pixis::Schema::Master::Result';

__PACKAGE__->load_components("PK::Auto", "TimeStamp", "Core");
__PACKAGE__->table("pixis_message_recipient");
__PACKAGE__->add_columns(
    id => {
        data_type => 'INTEGER',
        is_nullable => 0,
        is_auto_increment => 1,
        size => 32,
    },
    message_id => {
        data_type => 'CHAR',
        is_nullable => 0,
        size => 40,
    },
    to_profile_id => {
        data_type => 'CHAR',
        is_nullable => 0,
        size => 10,
    },
    opened_on => {
        data_type => 'DATETIME',
        is_nullable => 1,
#        set_on_update => 1,
    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to( 'message' => 'Pixis::Schema::Master::Result::Message', 'message_id' );
__PACKAGE__->belongs_to( 'to_profile' => 'Pixis::Schema::Master::Result::Profile', 'to_profile_id' );

1;
