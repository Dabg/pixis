use lib 't/lib';
use Test::FITesque;

my $users;
for (qw(alice bob carol)) {
    $users->{$_} = {
        email => $_.'@exampe.com',
        password => 'precuredaisuki',
        nickname => $_,
        firstname => $_,
        lastname => 'Smith',
    };
}

run_tests {
    test {
        [ 'Test::Pixis::Web::Message' ],
        [ 'setup_db' ],
        [ 'setup_web' ],
        [ 'signin', $users->{alice} ],
        [ 'signin', $users->{bob} ],
        [ 'signin', $users->{carol} ],
        [ 'send_message', $users->{alice}, $users->{bob} ],
        [ 'read_message', $users->{bob}, $users->{alice} ],
        [ 'cant_read_message', $users->{carol}, $users->{alice} ],
    },
};
