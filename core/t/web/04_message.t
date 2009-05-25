use lib 't/lib';
use Test::FITesque;

my ($users, $profiles, $mail);
for (qw(alice bob carol)) {
    $users->{$_} = {
        email => $_.'@exampe.com',
        password => 'precuredaisuki',
        nickname => $_,
        firstname => $_,
        lastname => 'Smith',
    };
    $profiles->{$_} = {
        name => $_,
        bio  => "Hi! I am $_",
    };
}

my $mail = {
    subject => 'GOOD PRICE VIAGRA',
    body => 'hehehe',
};

run_tests {
    test {
        [ 'Test::Pixis::Web::Profile' ],
        [ 'setup_db' ],
        [ 'setup_web' ],
        [ 'signin', $users->{alice} ],
        [ 'signin', $users->{bob} ],
        [ 'signin', $users->{carol} ],
        [ 'create', $profiles->{alice} ],
        [ 'create', $profiles->{bob} ],
    },
    test {
        [ 'Test::Pixis::Web::Message' ],
        [ 'send_message', $users->{alice}, $users->{bob}, $mail ],
        [ 'read_message', $users->{bob}, $users->{alice}, $mail ],
        [ 'cant_read_message', $users->{carol}, $users->{alice} ],
    },
};
