
package Pixis::Schema::Master::Result::PaymentTransaction;
use strict;
use warnings;
use base qw(Pixis::Schema::Base::MySQL);
use DateTime;

__PACKAGE__->load_components("PK::Auto", "InflateColumn::DateTime", "Core");
__PACKAGE__->table("pixis_payment_transaction");
__PACKAGE__->add_columns(
    "id" => {
        data_type => "INTEGER",
        is_auto_increment => 1,
        is_nullable => 0,
        size => 8,
    },
    order_id => {
        data_type => "CHAR",
        is_nullabe => 0,
        size => 12,
    },
    txn_type => {
        data_type => "CHAR",
        size      => 32,
        is_nullable => 0
    },
    ext_id => { # 
        data_type => "TEXT",
        is_nullable => 1,
    },
    amount => {
        data_type => "INTEGER",
        is_nullable => 0,
        size => 8
    },
    status => {
        data_type => "CHAR",
        is_nullable => 0,
        size => 32,
        default_value => "CREATED"
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
        name => 'txn_type_idx',
        fields => [ 'txn_type(32)' ],
    );
    $sqlt_table->add_index(
        name => 'ext_id_idx',
        fields => [ 'ext_id(255)' ],
    );
    $sqlt_table->add_index(
        name => 'order_id_idx',
        fields => [ 'order_id' ],
    );
    $self->next::method($sqlt_table);
    return ();
}

1;