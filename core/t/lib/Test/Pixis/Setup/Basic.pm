package Test::Pixis::Setup::Basic;
use Moose::Role;
use Pixis::Registry;
use Config::Any;
use Test::More;
use YAML ();
use namespace::clean -except => qw(meta);
use parent 'Test::FITesque::Fixture';

BEGIN {
    my $builder = Test::More->builder;
    binmode($builder->output, ':utf8');
    binmode($builder->failure_output, ':utf8');
    binmode($builder->todo_output, ':utf8');
}

has config => (
    is => 'rw',
    isa => 'HashRef',
    lazy_build => 1,
);

has 'configfile' => (
    is => 'rw',
    isa => 'Str',
    lazy_build => 1
);

sub _build_config {
    my $self = shift;
    my $filename = $self->configfile;
    my $cfg = Config::Any->load_files({
        files => [ $filename ],
        use_ext => 1,
    });
    return $cfg->[0]->{$filename};
}

sub _build_configfile {
    return $ENV{MYAPP_CONFIG} || 't/conf/pixis_test.yaml';
}

sub BUILDARGS {
    my ($self, %args) = @_;

    if (my $configfile = delete $args{configfile}) {
        $args{config} = YAML::LoadFile($configfile);
    }

    return { %args };
}

sub api {
    my ($self, $type) = @_;

    my $class = "Pixis::API::$type";
    my $config_key = "Schema::$type";

    my $config = $self->config;
    Class::MOP::load_class($class);

    my $api_config = $config->{$config_key} || {};
    if ($self->can('memcached') && $self->has_memcached) {
        $api_config->{cache} = $self->memcached;
    }
    return $class->new(%$api_config);
}

1;