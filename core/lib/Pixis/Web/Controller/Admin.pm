# $Id$

package Pixis::Web::Controller::Admin;
use strict;
use warnings;
use base qw(Catalyst::Controller::HTML::FormFu);

sub auto :Private {
    my ($self, $c) = @_;
    $c->forward('/auth/assert_roles', [ 'admin' ]);
    return ();
}

1;