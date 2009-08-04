package Pixis::Hub;
use Moose::Role;
use Pixis::Registry;
use namespace::clean -except => qw(meta);

sub api    {
    $_[1] or confess "No API name provided";
     Pixis::Registry->get(api => $_[1]);
}

sub schema { Pixis::Registry->get(schema => $_[1] || 'master') }

1;