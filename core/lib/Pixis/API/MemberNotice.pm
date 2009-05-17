package Pixis::API::MemberNotice;
use Moose;
use Pixis::Registry;
use namespace::clean -except => qw(meta);

with 'Pixis::API::Base::DBIC';

sub _build_resultset_constraints { return +{ is_expired => 1 } };

sub load_from_member {
    my ($self, $args) = @_;

    my $rows = $args->{rows} || 10;
    my @list = $self->resultset->search(
        { member_id => $args->{member_id} },
        { rows => $rows, order_by => 'created_on DESC' }
    );
    return wantarray ? @list : \@list;
}

__PACKAGE__->meta->make_immutable;

1;

