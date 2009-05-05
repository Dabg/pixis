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

{
    my $test = Test::FITesque::Test->new({
            data => [
                [ 'Test::Pixis::FITesque::Login' ],
                [ 'setup_db' ],
                [ 'setup_web' ],
                [ 'signin', $user ],
                [ 'login', $user ],
                [ 'logout' ],
                [ 'forgot_password', $user_reset ],
                [ 'login', $user_reset ],
            ]
        });

    $test->run_tests;
}
