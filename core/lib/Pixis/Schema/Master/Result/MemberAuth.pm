
package Pixis::Schema::Master::Result::MemberAuth;
use Moose;
use DateTime;
use Digest::SHA1 qw(sha1_hex);
use namespace::clean -except => qw(meta);

extends 'Pixis::Schema::Master::Result';

__PACKAGE__->load_components("PK::Auto", "TimeStamp", "Core");
__PACKAGE__->table("pixis_member_auth");
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
    auth_type => {
        data_type => "VARCHAR",
        is_nullable => 0,
        size => 8
    },
    auth_data => {
        data_type => "TEXT",
        is_nullable => 0,
    },
    is_active => {
        data_type => "TINYINT",
        is_nullable => 0,
        default_value => 1,
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
__PACKAGE__->add_unique_constraint(unique_auth_per_user => ["member_id", "auth_type"]);

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    my ($c) = grep { $_->name eq 'unique_auth_per_user' } $sqlt_table->get_constraints();
    $c->fields([ 'member_id', 'auth_type(8)' ]);
    $self->next::method($sqlt_table);
    return ();
}

sub populate_initial_data {
    my ($self, $schema) = @_;
    $schema->populate(
        MemberAuth => [
            [ qw(member_id auth_type auth_data) ],
            [ qw(1 password), sha1_hex('admin') ],
        ],
    );
    return ();
}

1;