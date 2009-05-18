package Test::Pixis::Fixture;
use Moose;
use MooseX::NonMoose;
use Moose::Exporter;
use Test::More;
use Test::Exception;
use namespace::clean -except => qw(meta);
use utf8;

BEGIN {
    extends 'Test::FITesque::Fixture', 'Moose::Object';
    Moose::Exporter->setup_import_methods();
}

sub init_meta {
    shift;
    my %options = @_;
    Moose->init_meta(%options);
    Moose::Util::MetaRole::apply_metaclass_roles(
        for_class               => $options{for_class},
        constructor_class_roles =>
            ['MooseX::NonMoose::Meta::Role::Constructor'],
    );
    return Class::MOP::class_of($options{for_class});
}

{
    no warnings 'redefine';
    sub new {
        my $class = shift;
    
        my $args = $class->BUILDARGS(@_);
        my $self = $class->SUPER::new($args);
        $self = $class->meta->new_object(
            __INSTANCE__ => $self,
            %$args
        );
        $self->BUILDALL($args);
        return $self;
    }
}

# Class::MOP::load_class does not call import (which is okay)
# so we need to detect the callee when we're required
{
    utf8->import;

    my $i = 0;
    while (my($pkg) = caller($i++)) {
        next if $pkg =~ /^(?:Class::MOP|Moose)/;

        Test::More->export_to_level($i);
        Test::Exception->export_to_level($i);

        last;
    }
}

1;
