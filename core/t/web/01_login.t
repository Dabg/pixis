use lib 't/lib';
use Test::FITesque;

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

run_tests {
    test { 
        [ 'Test::Pixis::Web::Login' ],
        [ 'setup_db' ],
        [ 'setup_web' ],
        [ 'signin', $user ],
        [ 'login', $user ],
        [ 'logout' ],
        [ 'forgot_password', $user_reset ],
        [ 'login', $user_reset ],
        [ 'reset_password_without_token', $user_reset ],
        [ 'signin_with_duplicate_email', $user ],
        [ 'activate_with_invalid_token', $user ],
    }
};
