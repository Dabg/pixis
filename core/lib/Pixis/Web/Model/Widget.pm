package Pixis::Web::Model::Widget;
use Moose;
use MooseX::AttributeHelpers;
use namespace::clean -except => qw(meta);

BEGIN { extends 'Catalyst::Model' }

has widgets => (
    metaclass => 'Collection::Has',
    is => 'ro',
    isa => 'HashRef',
    default => sub { +{} },
    provides => {
        set => 'widget_set',
        get => 'widget_get',
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
        my $class = "Pixis::Widget::$type";
        Class::MOP::load_class($class);
        $widget = $class->new();
        $self->widget_set( $type, $widget );
    }
    return $widget;
}

__PACKAGE__->meta->make_immutable;

1;
