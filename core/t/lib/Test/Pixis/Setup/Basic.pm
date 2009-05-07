package Test::Pixis::Setup::Basic;
use parent 'Test::FITesque::Fixture';
use Moose::Role;
use Test::More;
use Test::Pixis;

BEGIN {
    my $builder = Test::More->builder;
    binmode($builder->output, ':utf8');
    binmode($builder->failure_output, ':utf8');
    binmode($builder->todo_output, ':utf8');
}

1;