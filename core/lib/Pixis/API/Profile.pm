package Pixis::API::Profile::Type;
use Moose;
use namespace::clean -except => qw(meta);

has moniker => (is => 'ro', isa => 'Str', required => 1);
has name    => (is => 'ro', isa => 'Str', lazy => 1, default  => sub { $_[0]->moniker } );

__PACKAGE__->meta->make_immutable;

package Pixis::API::Profile;
use Moose;
use MooseX::AttributeHelpers;
use Pixis::Registry;
use namespace::clean -except => qw(meta);

has profile_types => (
    metaclass => 'Collection::Hash',
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1,
    required => 1,
    provides => {
        exists => 'is_supported',
        values => 'all_profile_types',
        get    => 'profile_type_get',
    }
);

with 'Pixis::API::Base::DBIC';

sub _build_profile_types {
    return { map { ($_->name, $_) } (
        Pixis::API::Profile::Type->new(
            moniker => 'PublicProfile', name => 'public'
        ),
        Pixis::API::Profile::Type->new(
            moniker => 'PrivateProfile', name => 'private'
        ),
    ) }
}

sub _get_unique_id {
    my ($self, $schema) = @_;
    my $key;
    my $attempt = 0;
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
    return $key->value;
}

sub create_type {
    my ($self, $type, $args) = @_;

    my $p = $self->profile_type_get($type);
    my $schema = Pixis::Registry->get(schema => 'master');

    my $guard = $schema->txn_scope_guard();

    $args->{id} = $self->_get_unique_id($schema);
    my $profile = $schema->resultset( $p->moniker )->create( $args );

    $guard->commit;

    return $profile;
}

sub load_from_member {
    my ($self, $args) = @_;

    my %where = ( member_id => $args->{member_id} );
    my $type = $args->{type} || 'public';

    my $p = $self->profile_type_get($type);
    my $schema = Pixis::Registry->get(schema => 'master');
    my @list = $schema->resultset($p->moniker)->search(
        \%where,
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
