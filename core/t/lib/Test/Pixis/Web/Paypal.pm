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

sub setup :Test :Plan(2) {
    my $self = shift;
    my $api = $self->api('PurchaseItem');
    my $registry = Pixis::Registry->instance;
    $registry->set(api => 'purchaseitem' => $api);
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
        $args->{created_on}  ||= \'NOW()';
        my $api = $registry->get(api => 'purchaseitem');
        $api->create($args);
    } "Created item";
}

sub payfor_it :Test :Plan(3) {
}

__PACKAGE__->meta->make_immutable;
