use strict;
use lib "t/lib";
use Test::FITesque;

run_tests {
    test {
        [ 'Test::Pixis::Widget::Menu' ],
        [ 'run' ],
        [ 'run_from_tt' ],
    }
};