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

sub update_from_form {
    my ($self, $user, $form) = @_;
    my $schema = Pixis::Registry->get(schema => 'master');
    my $rs = $schema->resultset('Profile');
    my %args = (
        bio => $form->param('bio') || undef,
        member_id => $user->id,
    );
    if ( $form->param('id') ) {
        $args{id} = $form->param('id');
    }

    my $profile = $rs->update_or_create(\%args);
    return $profile;
}

__PACKAGE__->meta->make_immutable;

1;
