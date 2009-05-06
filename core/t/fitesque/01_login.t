use Test::FITesque::Suite;
use Test::FITesque::Test;
use lib 't/lib';

my $user = {
    email => 'foo@example.com', 
    password => 'precuredaisuki',
    firstname => 'foo',
    lastname => 'bar',
};

my $user_reset = {
    email => 'foo@example.com', 
    password => 'kogaidan',
};

my $test = Test::FITesque::Suite->new;

my $signup = Test::FITesque::Test->new({
        data => [
        [ 'Test::Pixis::FITesque::Login' ],
        [ 'setup_db' ],
        [ 'setup_web' ],
        [ 'signin', $user ],
        [ 'login', $user ],
        [ 'logout' ],
        [ 'forgot_password', $user_reset ],
        [ 'login', $user_reset ],
        [ 'reset_password_without_token', $user_reset ],
        ]
    }
);

$test->add($signup);

$test->run_tests;
