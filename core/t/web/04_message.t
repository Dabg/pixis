use lib 't/lib';
use Test::FITesque;

my ($users, $profiles, $mail);
for (qw(alice bob carol)) {
    $users->{$_} = {
        email => $_.'@example.com',
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

$mail = {
    subject => 'GOOD PRICE VIAGRA',
    body => 'hehehe',
};

run_tests {
    test {
        [ 'Test::Pixis::Web::Profile' ],
        [ 'setup_db' ],
        [ 'setup_web' ],
        [ 'signin', $users->{alice} ],
        [ 'create', $profiles->{alice} ],
        [ 'signin', $users->{bob} ],
        [ 'create', $profiles->{bob} ],
        [ 'signin', $users->{carol} ],
        [ 'create', $profiles->{carol} ],
    },
    test {
        [ 'Test::Pixis::Web::Message' ],
        [ 'send_message', {
            from_user => $users->{alice}, 
            from_profile => $profiles->{alice}, 
            to_profile => $profiles->{bob}, 
            mail => $mail 
        }],
        [ 'read_message', {
            from_profile => $profiles->{alice},
            reader => $users->{bob},  
            mail => $mail,
        }],
        [ 'cant_read_message', {
            reader => $users->{carol}, 
            real_reader => $users->{bob},
            from_profile => $profiles->{alice}, 
            mail => $mail,
        }],
    },
};
