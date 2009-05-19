package Pixis::Web::Model::Widget;
use Moose;

BEGIN { extends 'Catalyst::Model' }

has widgets => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { +{} },
);

sub load {
    my ($self, $type) = @_;

    return $type if blessed $type;

    if (! defined $type || ! length $type) {
        confess "No type passed to load";
    }

    my $widget = $self->widgets->{ $type };

    if (! $widget) {
        my $class = "Pixis::Widget::$type";
        Class::MOP::load_class($class);
        $widget = $class->new();
        $self->widgets->{$type} = $widget;
    }
    return $widget;
}

__PACKAGE__->meta->make_immutable;

