
package Pixis::Schema::Master::Result::MessageToTags;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Pixis::Schema::Master::Result';

__PACKAGE__->load_components("TimeStamp", "Core");
__PACKAGE__->table("pixis_message_to_tags");
__PACKAGE__->add_columns(
    message_id => {
        data_type => 'CHAR',
        size => 40,
        is_nullable => 0,
    },
    profile_id => {
        data_type => 'CHAR',
        size => 10,
        is_nullable => 0,
    },
    tag_id => {
        data_type => 'CHAR',
        size => 40,
        is_nullable => 0,
    },
    created_on => {
        data_type => "DATETIME",
        is_nullable => 0,
        set_on_create => 1,
    }
);
__PACKAGE__->set_primary_key('message_id', 'profile_id', 'tag_id');
__PACKAGE__->belongs_to(
    'message',
    'Pixis::Schema::Master::Result::Message',
    { 'foreign.id' => 'self.message_id' },
);

__PACKAGE__->belongs_to(
    'tag',
    'Pixis::Schema::Master::Result::MessageTag',
    { 'foreign.id' => 'self.tag_id' },
);

sub sqlt_deploy_hook {
    my ($self, $sqlt) = @_;

    $sqlt->add_index(
        name   => 'tag_id_idx',
        fields => [ 'tag_id' ],
        type   => 'normal',
    );
}

1;