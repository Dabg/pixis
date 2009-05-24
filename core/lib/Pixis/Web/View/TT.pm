package Pixis::Web::View::TT;
use strict;
use warnings;
use base 'Catalyst::View::TT';

__PACKAGE__->config({
    TEMPLATE_EXTENSION => '.tt',
    EVAL_PERL => 1,
    });

1;
