package Pixis::Widget;
use Moose::Role;
use MooseX::Types::Path::Class;

# if running in stand alone mode
has view => ( is => 'ro', isa => 'Catalyst::View' );

has suffix => (
    is => 'ro',
    isa => 'Str',
    default => '.tt',
    predicate => 'has_suffix',
);
has template => (
    is => 'ro',
    isa => 'Path::Class::File',
    coerce => 1,
    required => 1,
    lazy_build => 1,
);

sub _build_template {
    my $self = shift;
    my $name = blessed $self;
    $name =~ s/^Pixis::Widget:://;
    my @args = ('widget' , map { lc $_ } split(/::/, $name) );
    if ($self->has_suffix) {
        $args[-1] .= $self->suffix;
    }
    return Path::Class::File->new( @args );
}

sub run {
    my $self = shift;
    return { template => $self->template->stringify };
}

1;

