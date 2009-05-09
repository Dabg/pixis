use lib 't/lib';
use Test::FITesque;

my $user = {
    email => 'main@example.com', 
    password => 'precuredaisuki',
    firstname => 'main',
    lastname => 'hiiragi',
};

my $profile = {
    bio => 'キャベツは特別！',
};

run_tests {
    test {
        [ 'Test::Pixis::Web::Profile' ],
        [ 'setup_db' ],
        [ 'setup_web' ],
        [ 'signin', $user ],
        [ 'login', $user ],
        [ 'create', $profile ],
    }
};
