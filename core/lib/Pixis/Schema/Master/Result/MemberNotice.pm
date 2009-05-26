
package Pixis::Schema::Master::Result::MemberNotice;
use Moose;

extends 'Pixis::Schema::Master::Result';

__PACKAGE__->load_components("PK::Auto", "Core");
__PACKAGE__->table("pixis_member_notice");
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
    is_expired => {
        data_type => 'TINYINT',
        is_nullable => 0,
        default_value => 0
    },
    expires_on => {
        data_type => "DATETIME",
        is_nullable => 0,
    },
    modified_on => {
        data_type => "TIMESTAMP",
        is_nullable => 0,
        default_value => \'NOW()',
    },
    created_on => {
        data_type => "DATETIME",
        is_nullable => 0,
    },
);
__PACKAGE__->set_primary_key("id");

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name => 'is_expired_idx',
        fields => [ 'is_expired' ]
    );
    return ();
}

1;
