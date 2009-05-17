package Pixis::API::Profile;
use Moose;
use Pixis::Registry;
use namespace::clean -except => qw(meta);

with 'Pixis::API::Base::DBIC';

around create => sub {
    my ($next, $self, $args) = @_;
    $args->{created_on} = \'NOW()';
    return $next->($self, $args);
};

sub load_from_member {
    my ($self, $args) = @_;

    my @list = $self->resultset->search(
        { member_id => $args->{member_id} },
        { order_by => 'id DESC' }
    );
    return wantarray ? @list : \@list;
}

__PACKAGE__->meta->make_immutable;

1;
