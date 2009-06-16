
package Pixis::Schema::Master::Result::MessageTag;
use Moose;
use utf8;
use namespace::clean -except => qw(meta);

extends 'Pixis::Schema::Master::Result';

__PACKAGE__->load_components("PK::Auto", "UTF8Columns", "DynamicDefault", "TimeStamp", "Core");
__PACKAGE__->table("pixis_message_tag");
__PACKAGE__->add_columns(
    id => {
        data_type => 'CHAR',
        size => 40,
        is_nullable => 0,
        dynamic_default_on_create => sub {
            Digest::SHA1::sha1_hex({}, time(), $$, rand());
        }
    },
    # 将来的にはmember_id -> tagのマッピングがないと、誰が持ち主か
    # わからなくなる。現在はシステムで定義するタグしか認めないので
    # 作っていない。（だからtagもunique key)
    tag => {
        data_type => 'VARCHAR',
        size => 255,
        is_nullable => 0
    },
    created_on => {
        data_type => "DATETIME",
        is_nullable => 0,
        set_on_create => 1,
    }
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint([ 'tag' ]);
__PACKAGE__->utf8_columns('tag');


sub populate_initial_data {
    my ($self, $schema) = @_;

    my $rs = $schema->resultset('MessageTag');
    $rs->create({
        tag => "Inbox",
    });
    $rs->create({
        tag => "Sent"
    });
    return;
}

1;