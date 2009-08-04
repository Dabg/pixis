
package Pixis::API::Base::DBIC;
use Moose::Role;
use MooseX::WithCache;
use namespace::clean -except => qw(meta);

with 'Pixis::Hub';

has 'resultset_moniker' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    lazy_build => 1,
);

has 'resultset_constraints' => (
    is => 'rw',
    isa => 'Maybe[HashRef]',
    predicate => 'has_resultset_constraints',
    lazy_build => 1,
);

has 'primary_key' => (
    is => 'rw',
    required => 1,
    lazy_build => 1
);

has 'cache_prefix' => (
    is => 'rw',
    required => 1,
    lazy_build => 1,
);

with_cache 'cache' => (backend => 'Cache::Memcached');

sub _build_resultset_moniker {
    my $self = shift;
    return (split(/::/, ref $self))[-1];
}

sub _build_resultset_constraints { return +{} }

sub _build_cache_prefix {
    my $self = shift;
    return join('.', split(/\./, ref $self));
}

sub txn_guard {
    my ($self, $name) = @_;
    return $self->schema($name)->txn_scope_guard();
}

sub resultset {
    my $self = shift;
    my $schema = $self->schema;
    my $rs     = $schema
        ->resultset($self->resultset_moniker)
        ->search($self->resultset_constraints)
    ;
    return $rs;
}

sub find {
    my ($self, @id) = @_;

    my $schema    = $self->schema;
    my $cache_key = [$self->cache_prefix, @id ];
    my $obj       = $self->cache_get($cache_key);
    if ($obj) {
        $obj = $schema->thaw($obj);
    } else {
        $obj = $self->resultset->find(@id);
        if ($obj) {
            $self->cache_set($cache_key, $schema->freeze($obj));
        }
    }
    return $obj;
}

sub load_multi {
    my ($self, @ids) = @_;
    my $schema = Pixis::Registry->get('schema' => 'master');

    # keys is a bit of a hassle
    my $rs = $self->resultset();
    my @keys = map { [ $self->cache_prefix, ref $_ ? @$_ : $_ ] } @ids;
    my $h = $self->cache_get_multi(@keys);

    my @ret;
    if ($h) {
        my $results = $h->{results};
        foreach my $key (@keys) {
            if (my $got = $results->{$key}) {
                push @ret, $schema->thaw($got);
            } else {
                push @ret, $self->find( ref $key->[1] ? @{$key->[1]} : $key->[1]);
            }
        }
    } else {
        @ret = map { $self->find($_) } @ids;
    }

    return wantarray ? @ret : \@ret;
}

sub _build_primary_key {
    my $self = shift;

    my $schema = Pixis::Registry->get('schema' => 'master');
    my $rs = $self->resultset();

    my @pk = $rs->result_source->primary_columns;
    return [ @pk ];
}

sub search {
    my ($self, $where, $attrs) = @_;

    $attrs ||= {};

    my $rs = $self->resultset();
    my $pk = $self->primary_key();

    my $multi = scalar @$pk > 1;
    $attrs->{select} ||= $pk;

    my @rows = $rs->search($where, $attrs);
    my @keys = $multi ?
        map {
            my $row = $_;
            [ map { $row->$_ } @$pk ]
        } @rows :
        map { $_->$pk } @rows
    ;
            
    return $self->load_multi(@keys);
}

sub create_from_form {
    my ($self, $form) = @_;

    my $schema = Pixis::Registry->get('schema' => 'master');
    local $form->{stash} = { schema => $schema };
    return $form->model->create();
}

sub create {
    my ($self, $args) = @_;
    my $rs = $self->resultset();
    return $rs->create($args);
}

sub update {
    my ($self, $args) = @_;

    my $schema = Pixis::Registry->get('schema' => 'master');

    my $pk = $self->primary_key();
    my $rs = $self->resultset();
    my $key = [ map { delete $args->{$_} } @$pk ];

    my $guard = $schema->txn_scope_guard;

    my $row = $self->find(@$key);
    if ($row) {
        while (my ($field, $value) = each %$args) {
            if (! $row->can($field)) {
                confess blessed $self . ": Attempt to update unknown column: $field";
            }
            $row->$field( $value );
        }
        $row->update;
        $self->cache_del([ $self->cache_prefix, @$key ]);
    }

    $guard->commit;

    return $row;
}

sub delete {
    my ($self, @id) = @_;

    my $schema = Pixis::Registry->get('schema' => 'master');

    my $guard = $schema->txn_scope_guard;
    foreach my $id (@id) {
        my $obj = $schema->resultset($self->resultset_moniker)->find($id);
        if ($obj) {
            $obj->delete;
        }

        my $cache_key = [$self->cache_prefix, $id ];
        $self->cache_del($cache_key);
    }
    
    $guard->commit;
    return ();
}

1;

__END__

=head1 NAME

Pixis::API::Base::DBIC - DBIx::Class-Based API Role

=head1 SYNOPSIS

    package MyApp::API::Foo;
    use Moose;

    with 'Pixis::API::Base::DBIC';

=head1 ATTRIBUTES

=head2 resultset_moniker

Contains the moniker given to $schema->resultset(). By default, the last
component of the  package name is used to create the default name
(i.e. "Baz" is used for package name Foo::Bar::Baz )

=head2 resultset_constraints

Contains a hashref of constraints to use when creating a resultset via
resultset() method. This allows you to filter rows by giving a default
constraint.

To disable temprarily, use local:

    local $api->{resultset_constraints};
    $api->resultset()->search(...);

=head2 primary_key

Holds the primary key for the resultset.

=head2 cache_prefix

Holds the prefix to add when caching rows.

=head1 METHODS

=head2 find($pk)

Returns a single based on the primary key.

=head2 resultset()

Returns a DBIx::Class::ResultSet object constructed using C<resultset_moniker>
and C<resultset_constraints>

=head2 create(\%args)

=head2 update(\%args)

=head2 delete(\%args)

=cut