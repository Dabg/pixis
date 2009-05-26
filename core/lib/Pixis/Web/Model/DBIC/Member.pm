package Pixis::Web::Model::DBIC::Member;
use strict;
use warnings;
use Pixis::Registry;

sub ACCEPT_CONTEXT {
    return Pixis::Registry->get(schema => 'master')->resultset('Member');
}

1;