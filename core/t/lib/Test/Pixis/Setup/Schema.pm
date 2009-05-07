package Test::Pixis::Setup::Schema;
use Moose::Role;
use Pixis::CLI::SetupDB;

has connect_info => (
    is => 'rw',
    isa => 'ArrayRef',
);

has schema => (
    is => 'rw',
    isa => 'Str',
    lazy_build => 1,
);

sub BUILD {
    my $self = shift;
    $self->connect_info($self->config->{'Schema::Master'}->{connect_info});
    $self;
}

sub setup_db {
    my $self = shift;
    # XXX FIX ME!!!
    if ($ENV{PIXIS_SKIP_SETUPDB}) {
        return;
    }
    my $connect_info = $self->connect_info;

    require Pixis::CLI::SetupDB;
    Pixis::CLI::SetupDB->new(
        dsn => $connect_info->[0],
        username => $connect_info->[1],
        password => $connect_info->[2] || '',
        drop => 1,
    )->run();
}

sub _build_schema {
    my $self = shift;
    my $connect_info = $self->connect_info;
    return Pixis::Schema::Master->connection( @$connect_info );
}

1;