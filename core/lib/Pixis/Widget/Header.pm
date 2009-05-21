package Pixis::Widget::Header;
use Moose;
use namespace::clean -except => qw(meta);

with 'Pixis::Widget';

has items => (
    metaclass => 'Collection::Array',
    is => 'ro',
    isa => 'ArrayRef[HashRef]',
    lazy_build => 1,
    provides => {
        push => 'item_add',
        elements => 'all_items',
    }
);

sub _build_items {
    return [
        {
            require_user => 1,
            uri => '/auth/logout',
            text => 'Logout',
            attrs => {
                id => 'hnav_logout',
            }
        },
        {
            require_user => 1,
            uri => "/member/settings",
            text => "Member Settings",
            attrs => {
                id => "hnav_settings"
            }
        },
        # These should be plugins
        {
            uri => "/message",
            text => "Message",
        },
        {
            uri => "/profile",
            text => "Profile",
        },
        {
            require_user => 1,
            uri => "/member/home",
            text => "Home",
            attrs => {
                id => "hnav_username",
            },
        },
        {
            require_no_user => 1,
            uri => sub {
                my $args = shift;
                my $uri = URI->new('/auth/login');
                $uri->query_form(
                    next => $args->{referer} || $args->{request}->uri
                );
                return $uri;
            },
            text => "Login",
            attrs => {
                id => "hnav_login",
            }
        }
    ]
}

around run => sub {
    my ($next, $self, @args) = @_;
    my $args = $next->($self, @args);

    my @items;
    foreach my $item ($self->all_items) {
        my %copy = %$item;
        while( my ($key, $value) = each %copy) {
            if (ref $value eq 'CODE') {
                $copy{$key} = $value->($args);
            }
        }
        push @items, \%copy;
    }

    $args->{items} = \@items;
    return $args;
};

1;
