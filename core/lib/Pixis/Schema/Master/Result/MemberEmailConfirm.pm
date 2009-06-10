package Pixis::Schema::Master::Result::MemberEmailConfirm;
use Moose;
use Digest::SHA1 ();
use namespace::clean -except => qw(meta);

extends 'Pixis::Schema::Master::Result';

__PACKAGE__->load_components("PK::Auto", "UTF8Columns", "DynamicDefault", "TimeStamp", "Core");
__PACKAGE__->table("pixis_member_email_confirm");
__PACKAGE__->add_columns(
    member_id => {
        data_type => "INTEGER",
        is_nullable => 0,
    },
    email => {
        data_type => "VARCHAR",
        is_nullable => 0,
        size => 256,
    },
    token => {
        data_type => "CHAR",
        is_nullable => 0,
        size => 40,
        dynamic_default_on_create => sub {
            Digest::SHA1::sha1_hex($$, $>, {}, rand(), time())
        }
    },
    created_on => {
        data_type => "DATETIME",
        is_nullable => 0,
        set_on_create => 1,
    },
);
__PACKAGE__->add_unique_constraint(unique_combo => ['member_id', 'email']);

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    my ($c) = grep { $_->name eq 'unique_combo' } $sqlt_table->get_constraints();
    $c->fields([ 'member_id', 'email(255)' ]);
    $self->next::method($sqlt_table);
}

1;
