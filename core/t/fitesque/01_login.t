use Test::FITesque::Test;
use lib 't/lib';

my $user = {
    email => 'foo@example.com', 
    password => 'precuredaisuki',
    firstname => 'foo',
    lastname => 'bar',
};

my $test = Test::FITesque::Test->new({
    data => [
        [ 'Test::Pixis::FITesque::Login' ],
        [ 'setup_db' ],
        [ 'setup_web' ],
        [ 'signin', $user ],
        [ 'login', $user ],
        [ 'logout' ],
    ]
});

$test->run_tests;
