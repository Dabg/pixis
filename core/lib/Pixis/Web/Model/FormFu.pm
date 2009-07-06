package Pixis::Web::Model::FormFu;
use Moose;
use MooseX::AttributeHelpers;
use MooseX::WithCache;
use namespace::clean -except => qw(meta);
use HTML::FormFu;

extends 'Catalyst::Model';

with_cache 'cache';

has config_file_path => (
    metaclass => 'Collection::Array',
    is => 'ro',
    isa => 'ArrayRef',
    default => sub { +[] },
    provides => {
        elements => 'all_config_file_path',
        push => 'add_config_file_path',
    }
);

has formfu_config => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { +{} },
);

has initialized_with_context => ( is => 'rw', isa => 'Bool', default => 0);

has proto => (
    is => 'rw',
    isa => 'HTML::FormFu',
    init_arg => undef,
    accessor => '_proto',
);

has localizer => (
    is => 'rw',
    isa => 'Object',
);

sub ACCEPT_CONTEXT {
    # If we haven't initialized with context yet, then do so
    my ($self, $c) = @_;

    if (! $self->initialized_with_context) {
        my $config = $self->formfu_config;
        my @paths;
        my %seen;
        foreach my $path (@{ $config->{config_file_path} }, $self->all_config_file_path) {
            next if $seen{ $path } ++;
            push @paths, $path;
        }
        $config->{config_file_path} = [@paths];
        $config->{query_type} = 'Catalyst';
        $self->localizer( $c->model('Data::Localize') );
        $self->initialized_with_context(1);
    }
    return $self;
}

sub load {
    my ($self, $name, $args) = @_;

    my $form = $self->cache_get($name);
    if (! $form) {
        $form = HTML::FormFu->new( 
            Catalyst::Utils::merge_hashes( $self->formfu_config, $args ) );
        $form->add_localize_object($self->localizer);
        $form->load_config_filestem($name);

        $self->cache_set($name, $form);
    }
    return $form;
}

__PACKAGE__->meta->make_immutable;

1;
