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
        [ 'check_active_member', 0 ],
        [ 'create_member', 1 ],
        [ 'activate_member', 1 ],
        [ 'check_active_member', 1 ],
        [ 'check_followers' ],
        [ 'delete_member', 0 ],
        [ 'delete_member', 1 ],
    }
};

