package Pixis::Schema::Master::Result;
use Moose;
use MooseX::NonMoose;

extends 'DBIx::Class';

__PACKAGE__->mk_classdata('engine' => 'InnoDB');
__PACKAGE__->mk_classdata('charset' => 'UTF8');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->extra->{mysql_table_type} = $self->engine;
    $sqlt_table->extra->{mysql_charset}    = $self->charset;
    return ();
};

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
