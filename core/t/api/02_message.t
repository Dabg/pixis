use strict;
use utf8;
use lib "t/lib";

use Test::FITesque;

run_tests {
    test {
        [ 'Test::Pixis::API::Member',
            configfile => 't/conf/pixis_test.yaml' ],
        [ 'setup_db' ],
        [ 'setup' ],
        [ 'create_member', 0 ],
        [ 'activate_member', 0 ],
        [ 'create_member', 1 ],
        [ 'activate_member', 1 ],
    },
    test {
        [ 'Test::Pixis::API::Message',
            configfile => 't/conf/pixis_test.yaml' ],
        [ 'setup' ],
        [ 'send_message', { from => 0, to => 1 } ],
        [ 'send_message', { from => 0, to => 1 } ],
        [ 'check_mailbox', { profile => 0, count => 0, tag => 'Inbox' } ],
        [ 'check_mailbox', { profile => 1, count => 2, tag => 'Inbox' } ],
        [ 'check_mailbox', { member => 0, count => 0, tag => 'Inbox' } ],
        [ 'check_mailbox', { member => 1, count => 2, tag => 'Inbox' } ],
        [ 'check_mailbox', { profile => 0, count => 2, tag => 'Sent' } ],
        [ 'check_mailbox', { profile => 1, count => 0, tag => 'Sent' } ],
        [ 'check_mailbox', { member => 0, count => 2, tag => 'Sent' } ],
        [ 'check_mailbox', { member => 1, count => 0, tag => 'Sent' } ],
    },
    test {
        [ 'Test::Pixis::API::Member',
            configfile => 't/conf/pixis_test.yaml' ],
        [ 'delete_member', 0 ],
        [ 'delete_member', 1 ],
    };
};
