package Pixis::API::ProfileType;
use Moose;
use Pixis::Registry;
use namespace::clean -except => qw(meta);

with 'Pixis::API::Base::DBIC';

sub load_all {
    my ($self) = @_;
    return $self->resultset->all;
}

__PACKAGE__->meta->make_immutable;

1;
