package Test::Pixis::Web::Paypal;
use Moose;

BEGIN {
    extends 'Test::Pixis::Fixture';
    with 
        'Test::Pixis::Setup::Basic',
        'Test::Pixis::Setup::Schema',
        'Test::Pixis::Web::Common',
    ;
}

sub setup  {
    my $self = shift;
    my $api = $self->api('PurchaseItem');
    my $registry = Pixis::Registry->instance;
    $registry->set(api => 'purchaseitem' => $api);
    $registry->set(api => 'order' => $self->api('Order'));
    $registry->set(api => 'member' => $self->api('Member'));
    $registry->set(schema => 'master' => $self->schema);
}

sub create_purchase_item :Test :Plan(1) {
    my ($self, $args) = @_;
    my $registry = Pixis::Registry->instance;

    lives_ok {
        $args ||= {};
        $args->{id}          ||= "ame-chang-001";
        $args->{store_name}  ||= "testme";
        $args->{name}        ||= "Cnady";
        $args->{price}       ||= 1000;
        $args->{description} ||= "甘〜い飴ちゃんだよ！";
        my $api = $registry->get(api => 'purchaseitem');
        $api->create($args);
    } "Created item";
}

sub place_order :Test :Plan(2) {
    my ($self, $args) = @_;

    lives_ok {
        my $api = Pixis::Registry->get(api => 'order');
        my $member = Pixis::Registry->get(api => 'member')->load_from_email($args->{email}) or die "No such member";


        my %order_args = (
            $args->{amount} || 1000,
        );
        $api->create(\%order_args);
    } "Created order"
}

sub pay_for_it :Test :Plan(3) {
    

}

__PACKAGE__->meta->make_immutable;
