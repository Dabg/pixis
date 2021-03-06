
package Pixis::API::Order;
use Moose;
use namespace::clean -except => qw(meta);
use Pixis::API::Base::DBIC;

with 'Pixis::API::Base::DBIC';

around create => sub {
    my ($next, $self, $args) = @_;

    if (! $args->{id}) {
        my $key;
        my $attempt = 0;
        my $schema = Pixis::Registry->get(schema => 'Master');
        while (! $key ) {
            $key = $schema->resultset('OrderUniqueId')->search(
                {
                    taken_on => \'IS NULL',
                },
                {
                    rows => 1
                }
            )->single;
            
            my $updated = $schema->resultset('OrderUniqueId')->search(
                {
                    value => $key->value,
                    taken_on => \'IS NULL'
                }
            )->update({ taken_on => \'NOW()' });
            if (! $updated) {
                $key = undef;
            }
            last if $attempt++ > 100;
        }
        if (! $key ) {
            confess "Failed to get a unique key for order";
        }
        $args->{id} = $key->value;
    }
    $next->($self, $args);
};

sub create_txn {
    my ($self, $args) = @_;

    my $txn_args = $args->{txn};
    my %args     = (
        %$txn_args, 
        order_id => $args->{order_id},
    );

    my $schema = Pixis::Registry->get(schema => 'master');
    my $guard  = $schema->txn_scope_guard;
    my $txn    = $schema->resultset('PaymentTransaction')->create(\%args);
    $guard->commit;

    return $txn;
}

sub change_status {
    my ($self, $args) = @_;

    my $schema = Pixis::Registry->get(schema => 'master');
    my $guard  = $schema->txn_scope_guard();

    my $order = $self->find($args->{order_id});
    if (! $order) {
        confess "No such order: $args->{order_id}";
    }

    if (my $txn = $args->{txn}) {
        local $txn->{order_id} = $args->{order_id};
        $self->change_txn_status($txn);
    }

    my $old = $order->status();
    $order->status($args->{status});
    $order->update;

    my $message = "CHANGE $old => $args->{status} " . ($args->{message} || '');

    $self->log_action( {
        order_id => $order->id,
        message => $message
    } );

    $guard->commit;

    return ();
}

sub log_action {
    my ($self, $args) = @_;

    my $order = $self->find( $args->{order_id} );
    if (! $order) {
        confess "No such order: $args->{order_id}";
    }

    return Pixis::Registry->get(schema => 'master')->resultset('OrderAction')->create( {
        order_id => $order->id,
        message  => $args->{message}
    } );
}

sub change_txn_status {
    my ($self, $args) = @_;

    my $schema = Pixis::Registry->get(schema => 'master');
    my $guard  = $schema->txn_scope_guard;

    my $txn = $schema->resultset('PaymentTransaction')->search(
        {
            id => $args->{id},
            order_id => $args->{order_id},
            txn_type => $args->{txn_type},
        }
    )->single;

    if (! $txn) {
        confess "Could not find transaction by id: $args->{id}";
    }

    foreach my $field qw(status ext_id) {
        $txn->$field( $args->{$field} ) if exists $args->{$field};
    }
    $txn->update;

    $guard->commit();

    return ();
}

sub match_txn {
    my ($self, $args) = @_;

    my $schema = Pixis::Registry->get(schema => 'master');
    my $guard  = $schema->txn_scope_guard;

    my $txn = $schema->resultset('PaymentTransaction')->search({
            order_id => $args->{order_id},
            id => $args->{txn}->{id},
            ext_id => $args->{txn}->{ext_id},
        }
    )->single;

    my $order;
    if ($txn) {
        $order = $self->find($txn->order_id);
    }

    $guard->commit;
    return $order || ();
}

1;
