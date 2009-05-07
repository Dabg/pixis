package Test::Pixis::Web::Paypal;
use Moose;

with 
    'Test::Pixis::Setup::Basic',
    'Test::Pixis::Setup::Schema',
    'Test::Pixis::Web::Common',
;

use utf8;

use parent 'Test::FITesque::Fixture';

use Test::More;
use Test::Exception;

sub buyit :Test :Plan(3) {
}

