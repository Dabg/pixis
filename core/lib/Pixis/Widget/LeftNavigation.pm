package Pixis::Widget::LeftNavigation;
use Moose;
use MooseX::AttributeHelpers;
use Moose::Util::TypeConstraints;
use namespace::clean -except => qw(meta);

with 'Pixis::Widget';

has logo => (
    metaclass => 'Collection::Hash',
    is => 'ro',
    isa => 'HashRef',
    default => sub { +{} },
    provides => {
        set => 'logo_set',
        get => 'logo_get',
    }
);

subtype 'Pixis::Widget::LeftNavigation::Item'
    => as 'HashRef'
    => where {
        exists $_->{uri} &&
                $_->{text}
    }
;
                
has items => (
    metaclass => 'Collection::Array',
    is => 'ro',
    isa => 'ArrayRef[Pixis::Widget::LeftNavigation::Item]',
    default => sub { +[] },
    provides => {
        elements => 'all_items',
        push => 'item_add',
        clear => 'items_clear'
    }
);

has submenus => (
    metaclass => 'Collection::Array',
    is => 'ro',
    isa => 'ArrayRef[Pixis::Widget::LeftNavigation::Item]',
    default => sub { +[] },
    provides => {
        elements => 'all_submenus',
        push => 'submenu_add',
        clear => 'submenus_clear',
        count => 'submenu_count',
    }
);

around run => sub {
    my ($next, $self, @args) = @_;
    my $args = $next->($self, @args);

    $args->{items} = [ $self->all_items ];
    if ($self->submenu_count > 0) {
        $args->{submenu} = [ $self->all_submenus ];
    }

    $args->{logo} = $self->logo;

    return $args;
};

around _build_template 
    => sub { return Path::Class::File->new('widget', 'left.tt') };

__PACKAGE__->meta->make_immutable;

1;
