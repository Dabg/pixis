package Pixis::Web::View::Email;

use strict;
use warnings;
use base 'Catalyst::View::Email';

__PACKAGE__->config(
    stash_key => 'email'
);

1;
