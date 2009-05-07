package Test::Pixis::Setup::Schema;
use Moose::Role;
use Test::Pixis;
use Pixis::CLI::SetupDB;

sub setup_db {
    # XXX FIX ME!!!
    my $t = Test::Pixis->instance();

    if ($ENV{PIXIS_SKIP_SETUPDB}) {
        return;
    }
    my $connect_info = $t->config->{'Schema::Master'}->{connect_info};

    Pixis::CLI::SetupDB->new(
        dsn => $connect_info->[0],
        username => $connect_info->[1],
        password => $connect_info->[2] || '',
        drop => 1,
    )->run();
}

1;