package Pixis::Widget;
use Moose::Role;
use Moose::Util::TypeConstraints;
use MooseX::Types::Path::Class;
use namespace::clean -except => qw(meta);
use URI;

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

has is_esi => (
    is => 'rw',
    isa => 'Bool',
    default => 0
);

class_type 'URI';
coerce 'URI'
    => from 'Str'
    => via { URI->new($_) }
;
has esi_uri => (
    is => 'ro',
    isa => 'URI',
    coerce => 1,
    lazy_build => 1
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

sub _build_esi_uri {
    my $self = shift;
    my $name = blessed $self;
    $name =~ s/^Pixis::Widget:://;
    my @args = ('widget' , map { lc $_ } split(/::/, $name) );
    URI->new(join('/', @args));
}

sub run {
    my $self = shift;
    my %args = (
        template => $self->template->stringify
    );
    if ($self->is_esi) {
        $args{is_esi} = 1;
        $args{esi_uri} = $self->esi_uri;
    }
    return \%args;
}

1;

