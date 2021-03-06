package Pixis::Widget;
use Moose::Role;
use Moose::Util::TypeConstraints;
use MooseX::AttributeHelpers;
use MooseX::Types::Path::Class;
use namespace::clean -except => qw(meta);
use URI;

with 'Pixis::Hub';

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

has use_esi => (
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
    lazy_build => 1,
    clearer => 'esi_uri_clear',
);

has query_params => (
    metaclass => 'Collection::Hash',
    is => 'ro',
    isa => 'HashRef',
    default => sub { +{} },
    provides => {
        set => 'query_param_set',
        get => 'query_param_get',
        exists => 'query_param_exists',
        clear => 'query_params_clear',
    }
);

sub _build_template {
    my $self = shift;
    my $name = blessed $self;
    $name =~ s/^.+::Widget:://;
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
    my @args = ('', 'widget' , map { $_ } split(/::/, $name) );
    my $uri  = URI->new(join('/', @args));
    $uri->query_form($self->query_params);
    return $uri;
}

sub reset {
    my $self = shift;
    $self->esi_uri_clear();
    $self->query_params_clear();
    return ();
}

sub run {
    my ($self, $args) = @_;

    $self->reset();

    my %args = $args ? %$args : {};
    $args{template} = $self->template->stringify;

    if ($self->use_esi || $args{use_esi}) {
        $args{use_esi} = 1;
        if ($args{user} && !$self->query_param_exists($args{user}->id)) {
            $self->query_param_set(user_id => $args{user}->id);
        }
    }

    $self->query_param_set( referer => $args->{request}->uri);
    if (my $referer = $args->{request}->param('referer')) {
        $args{referer} = $referer;
    }

    return \%args;
}

1;

