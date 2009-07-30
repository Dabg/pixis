package Pixis::Web::Model::Widget;
use Moose;
use MooseX::AttributeHelpers;
use namespace::clean -except => qw(meta);

BEGIN { extends 'Catalyst::Model' }

has widgets => (
    metaclass => 'Collection::Hash',
    is => 'ro',
    isa => 'HashRef',
    default => sub { +{} },
    provides => {
        set => 'widget_set',
        get => 'widget_get',
    }
);

# Model::Widget:
#    namespaces:
#       - MyApp::Widget
#       - Pixi::Widget
has namespaces => (
    metaclass => 'Collection::Array',
    is => 'ro',
    isa => 'ArrayRef[Str]',
    default => sub { [ qw(Pixis::Widget) ] },
    provides => {
        elements => 'all_namespaces'
    }
);

sub load {
    my ($self, $type) = @_;

    return $type if blessed $type;

    if (! defined $type || ! length $type) {
        confess "No type passed to load";
    }

    my $widget = $self->widget_get( $type );

    if (! $widget) {
        my $class;
        foreach my $namespace ($self->all_namespaces) {
            $class = "$namespace\::$type";
            eval {
                Class::MOP::load_class($class);
            };
            last if ! $@;
            $class = undef;
        }
        if (! $class) {
            confess "Could not find a widget by the name of $type";
        }
        $widget = $class->new();
        $self->widget_set( $type, $widget );
    }
    return $widget;
}

__PACKAGE__->meta->make_immutable;

1;
