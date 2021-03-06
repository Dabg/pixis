package Test::Pixis::Setup::Memcached;
use Moose::Role;
use Moose::Util::TypeConstraints;
use MooseX::AttributeHelpers;
use IO::Socket::INET ();
use Digest::MD5 ();
use Test::More;
use namespace::clean -except => qw(meta);

has memcached_servers => (
    metaclass => 'Collection::Array',
    is => 'ro',
    isa => 'ArrayRef[Str]',
    default => sub { +[ '127.0.0.1:11211' ] },
    provides => {
        elements => 'all_memcached_servers'
    },
);

has memcached_key_generator => (
    is => 'ro',
    does => 'MooseX::WithCache::KeyGenerator',
    required => 1,
    lazy_build => 1,
);

has memcached_namespace => (
    is => 'rw',
    isa => 'Str',
    default => Digest::MD5::md5_hex(join('.', time(), $$, {}, rand()) )
);

class_type 'Cache::Memcached';
class_type 'Cache::Memcached::Fast';
class_type 'Cache::Memcached::libmemcached';

has memcached => (
    is => 'ro',
    isa => 'Cache::Memcached | Cache::Memcached::Fast | Cache::Memcached::libmemcached',
    lazy_build => 1
);

sub _build_memcached_key_generator {
    require MooseX::WithCache::KeyGenerator::DumpChecksum;
    return MooseX::WithCache::KeyGenerator::DumpChecksum->new();
}

sub _build_memcached {
    my $self = shift;
    require Cache::Memcached;
    return Cache::Memcached->new({
        servers => $self->memcached_servers,
        namespace => $self->memcached_namespace,
    });
}

sub check_memcached {
    my $self = shift;

    # check connectivity
    my $server_ok = 0;
    foreach my $server ( $self->all_memcached_servers ) {
        my ($host, $port) = split(/:/, $server);
        my $socket = IO::Socket::INET->new( 
            PeerHost => $host,
            PeerPort => $port,
        );
        if ($socket) {
            $server_ok = 1;
            last;
        }
    }

    return $server_ok;
}

1;
