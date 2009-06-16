
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
        keys   => 'profile_type_keys',
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

sub find {
    my ($self, $id) = @_;

    my $schema = Pixis::Registry->get(schema => 'master');

    # XXX use join?
    my $link  = $schema->resultset('MemberToProfile')->search( { profile_id => $id } )->single;
    my $profile;
    if ($link) {
        $profile = $schema->resultset( $link->moniker )->find($id);
    }

    return $profile ? $profile : ();
}

sub search_by_type {
    my ($self, $type, @args) = @_;

    my $schema = Pixis::Registry->get(schema => 'master');

    my $profile = $schema->resultset( $type->moniker )->search(@args);

    return $profile;
}

sub create_type {
    my ($self, $type, $args) = @_;

    my $p = $self->profile_type_get($type);
    if (! $p) {
        confess "No such profile $type. Available profiles are: " . (
            join(", ", $self->profile_type_keys) );
    }
    my $schema = Pixis::Registry->get(schema => 'master');

    my $guard = $schema->txn_scope_guard();

    $args->{id} = $self->_get_unique_id($schema);

    # need to create the actual profile, then the mapping from
    # member -> profile
    my $profile = $schema->resultset( $p->moniker )->create( $args );

    $schema->resultset('MemberToProfile')->create(
        {
            member_id => $args->{member_id},
            profile_id => $profile->id,
            moniker => $p->moniker,
        }
    );

    $guard->commit;

    return $profile;
}

sub load_from_member {
    my ($self, $args) = @_;

    my %where = ( member_id => $args->{member_id} );
    if (my $type = $args->{type}) {
        my $p = $self->profile_type_get($type);
        $where{moniker} = $p->moniker;
    }

    my $schema = Pixis::Registry->get(schema => 'master');

    my @links = $schema->resultset('MemberToProfile')->search(
        \%where,
        { order_by => 'moniker' }
    );
    my %moniker2ids;
    foreach my $link (@links) {
        $moniker2ids{ $link->moniker } ||= [];
        push @{ $moniker2ids{ $link->moniker } }, sprintf('%010d', $link->profile_id);
    }

    my @list;
    while (my($moniker, $ids) = each %moniker2ids) {
        my @profiles = $schema->resultset($moniker)->search(
            { id => { -in => $ids } },
        )->all;
        push @list, @profiles;
    }
    return wantarray ? @list : \@list;
}

sub update {
    my ($self, $args) = @_;

    my $schema = Pixis::Registry->get(schema => 'Master');
    my $guard  = $schema->txn_scope_guard;

    my $id = delete $args->{profile_id};
    my $link = $schema->resultset('MemberToProfile')->search(
        {
            member_id  => $args->{member_id},
            profile_id => $id,
        }
    )->single;

    my $profile = $schema->resultset( $link->moniker )->find($id) or return;
    $profile->update( $args );

    $guard->commit;
    return $profile;
}

sub delete {
    my ($self, $args) = @_;

    my $schema = Pixis::Registry->get(schema => 'Master');
    my $guard  = $schema->txn_scope_guard;

    my $id = delete $args->{profile_id};
    my $link = $schema->resultset('MemberToProfile')->search(
        {
            member_id  => $args->{member_id},
            profile_id => $id,
        }
    )->single;

    my $profile = $schema->resultset( $link->moniker )->search(
        {
            id => $id,
        }
    )->delete();
    $link->delete;

    $guard->commit;

    return ();
}

sub detect_type {
    my ($self, $profile) = @_;
    my $moniker = [ split('::', ref $profile) ]->[-1];
    return [grep {$_->moniker eq $moniker} $self->all_profile_types]->[0];
}

__PACKAGE__->meta->make_immutable;

package Pixis::API::Profile::Type; ## no critic
use Moose;
use namespace::clean -except => qw(meta);

has moniker => (is => 'ro', isa => 'Str', required => 1);
has name    => (is => 'ro', isa => 'Str', lazy => 1, default  => sub { $_[0]->moniker } );

__PACKAGE__->meta->make_immutable;

1;
