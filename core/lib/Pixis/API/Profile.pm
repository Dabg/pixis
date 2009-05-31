package Pixis::API::Profile;
use Moose;
use Pixis::Registry;
use namespace::clean -except => qw(meta);

with 'Pixis::API::Base::DBIC';

around create => sub {
    my ($next, $self, $args) = @_;

    if (! $args->{id}) {
        my $key;
        my $attempt = 0;
        my $schema = Pixis::Registry->get(schema => 'Master');
        while (! $key ) {
            $key = $schema->resultset('ProfileUniqueId')->search(
                {
                    taken_on => \'IS NULL',
                },
                {
                    rows => 1
                }
            )->single;
            
            my $updated = $schema->resultset('ProfileUniqueId')->search(
                {
                    value => $key->value,
                    taken_on => \'IS NULL'
                }
            )->update({ taken_on => \'NOW()' });
            if (! $updated) {
                $key = undef;
            }
            last if $attempt++ > 100;
        }
        if (! $key ) {
            confess "Failed to get a unique key for order";
        }
        $args->{id} = $key->value;
    }

    $next->($self, $args);
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
