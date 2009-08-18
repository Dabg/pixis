package Pixis::Hub;
use Moose::Role;
use Pixis::Registry;
use namespace::clean -except => qw(meta);

sub registry { ## no critic
    shift;
    # XXX the initialization code is currently at Model::API. Should this
    # be changed?
    return Pixis::Registry->instance();
}

sub api    {
    $_[1] or confess "No API name provided";
     Pixis::Registry->get(api => $_[1]);
}

sub schema { Pixis::Registry->get(schema => $_[1] || 'master') }

1;