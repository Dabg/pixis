use lib 't/lib';
use utf8;
use Test::FITesque;

my $user = {
    email => 'main@example.com', 
    password => 'precuredaisuki',
    firstname => 'main',
    lastname => 'hiiragi',
};

my $profile = {
    name => 'キャベツ星人',
    bio => 'キャベツは特別！',
};

my $profile2 = {
    name => 'foobar',
    bio => 'hoge',
};

run_tests {
    test {
        [ 'Test::Pixis::Web::Profile' ],
        [ 'setup_db' ],
        [ 'setup_web' ],
        [ 'signin', $user ],
        [ 'login', $user ],
        [ 'create', $profile ],
        [ 'edit', $profile, $profile2 ],
    }
};
