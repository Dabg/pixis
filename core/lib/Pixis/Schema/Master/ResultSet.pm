package Pixis::Schema::Master::ResultSet;
use Moose;
use MooseX::NonMoose;
use namespace::clean -except => qw(meta);

extends 'DBIx::Class::ResultSet';

1;