use lib 't/lib';
use Test::FITesque;

my $user = {
    email => 'foo@example.com', 
    password => 'precuredaisuki',
    firstname => 'foo',
    lastname => 'bar',
};

run_tests {
    test { 
        [ 'Test::Pixis::Web::Paypal' ],

        # XXX TODO: Can't we just call setup() once? (via Moose?)
        [ 'setup_db' ],
        [ 'setup' ],

        # XXX TODO: We probably need to hand wave this and put the item and
        # the order via the API, not from web, and then just test paypal itself

        # Make sure there's something in the purchase item list
        [ 'create_purchase_item' ],

        # Place an order via the API
        # [ 'FIX ME' ]

        # Pay for it via paypal
        [ 'login', $user ],
        [ 'payfor_it' ],

        # Make sure by checking the paypal site
        [ 'logout' ],
    }
};
