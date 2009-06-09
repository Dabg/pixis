# $Id$

package Pixis::Plugin::Core;
use Moose;
use MooseX::AttributeHelpers;
use namespace::clean -except => qw(meta);
with 'Pixis::Plugin';

has namespaces => (
    metaclass => 'Collection::Array',
    is => 'ro',
    isa => 'ArrayRef[Str]',
    default => sub { +[ qw( Pixis::API ) ] },
    provides => {
        elements => 'all_namespaces'
    }
);

has apis => (
    metaclass => 'Collection::Array',
    is => 'ro',
    isa => 'ArrayRef[Str]',
    lazy_build => 1,
    provides => {
        elements => 'all_apis',
        push     => 'api_add',
    }
);

sub _build_include_path {
    return []; # Core templates should be read in by the app, not the plugin
}

sub _build_apis {
    return [ qw(
        Member 
        MemberAuth 
        MemberRelationship 
        MemberNotice 
        Order 
        Payment::Paypal 
        Payment::Transaction 
        PurchaseItem 
        Profile 
        Message 
        MessageRecipient
  ) ]
}

sub BUILD {
    my ($self, $args) = @_;

    if (my $list = $args->{additional_apis}) {
        $self->api_add($_) for @$list;
    }
    return $self;
}

before register => sub {
    my ($self, $c) = @_;

    my $config = $c->config();

    my $registry = Pixis::Registry->instance;
    foreach my $name qw(Master) {
        my $schema_config = $config->{"Schema::$name"};
        my $module = "Pixis::Schema::$name";
        Class::MOP::load_class($module);
        my $schema = $module->connection( @{$schema_config->{connect_info}} );
        $registry->set("schema" => $name => $schema);
    }

    my @list;
    foreach my $name ($self->all_apis) {
        my $api_config = $config->{"API::$name"} || {};
        my $module;
        foreach my $namespace ($self->all_namespaces) {
            eval {
                my $tmp = "$namespace\::$name";
                Class::MOP::load_class($tmp);
                $module = $tmp;
            };
            last if $module;
        }
        if (! $module) {
            confess "Could not find an API by the name $name";
        }

        eval {
            my $api = $module->new(%$api_config);
            push @list, $api;
        };
        if ($@) {
            warn && confess;
        }
    }
    $self->extra_api(\@list);
    return ();
};

__PACKAGE__->meta->make_immutable();

1;