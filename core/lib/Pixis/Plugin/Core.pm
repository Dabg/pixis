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

sub _build_include_path {
    return []; # Core templates should be read in by the app, not the plugin
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
    foreach my $name qw(
        Member 
        MemberAuth 
        MemberRelationship 
        MemberNotice 
        Order 
        Payment::Paypal 
        Payment::Transaction 
        PurchaseItem 
        Profile 
        ProfileType 
        Message 
        MessageRecipient
    ) {
        my $api_config = $config->{"API::$name"} || {};
        my $module;
        foreach my $namespace ($self->all_namespaces) {
            $module = "$namespace\::$name";
            eval {
                Class::MOP::load_class($module);
            };
            last if !$@;
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