package Test::Pixis::Setup::Basic;
use Moose::Role;
use MooseX::AttributeHelpers;
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
    required => 1,
    lazy_build => 1,
);

has 'configfile' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    lazy_build => 1
);

has members => (
    metaclass => 'Collection::Array',
    is => 'rw',
    isa => 'ArrayRef[HashRef]',
    required => 1,
    lazy_build => 1,
    provides => {
        count => 'members_count',
    }
);

sub _build_members {
    return [
        +{
            email     => 'taro-test@perlassociation.org',
            nickname  => 'testtaro',
            firstname => '太郎',
            lastname  => 'テスト',
            password  => 'testing',
            activation_token => Digest::SHA1::sha1_hex($$, rand(), time()),
            profiles  => [
                {
                    type => 'public',
                    display_name => '太郎さん',
                    bio => 'あちこち旅してまいりやんした',
                }
            ]
        },
        +{
            email     => 'hanako-test@perlassociation.org',
            nickname  => 'testhanako',
            firstname => '花子',
            lastname  => 'テスト',
            password  => '#$FSOkdi23-$1~',
            activation_token => Digest::SHA1::sha1_hex($$, rand(), time()),
            profiles  => [
                {
                    type => 'public',
                    display_name => '花子さん',
                    bio => 'どこまでもついていきやんす',
                }
            ]
        }
    ]
}

sub get_member {
    my ($self, $idx) = @_;

    my $api = Pixis::Registry->get(api => 'member');
    my $member;

    if ( $self->members->[$idx]->{id} ) {
        $member = $api->find( $self->members->[$idx]->{id} );
    } else {
        $member = $api->load_from_email( $self->members->[$idx]->{email} );
    }

    if (! $member) {
        require Data::Dumper;
        confess "Failed to load member ($idx): " . Data::Dumper::Dumper($self->members->[$idx]);
    }
    return $member;
}

sub get_profile {
    my ($self, $idx, $type) = @_;
    $type ||= 'public';

    my $member = $self->get_member($idx);
    my ($profile) = Pixis::Registry->get(api => 'profile')->load_from_member( {
        member_id => $member->id,
        type      => $type
    });

    if (! $profile) {
        require Data::Dumper;
        confess "Failed to load profile ($idx, $type): " . Data::Dumper::Dumper($self->members->[$idx]);
    }
    return $profile;
}

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
    my $config_key = "API::$type";

    my $config = $self->config;
    Class::MOP::load_class($class);

    my $api_config = $config->{$config_key} || {};
    if ($self->can('memcached') && $self->has_memcached) {
        $api_config->{cache} = $self->memcached;
    }
    return $class->new(%$api_config);
}

1;