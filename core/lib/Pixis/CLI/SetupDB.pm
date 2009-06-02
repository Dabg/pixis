# $Id: /mirror/pixis/Pixis-Core/trunk/lib/Pixis/CLI/SetupDB.pm 101264 2009-02-27T05:10:06.352581Z daisuke  $

package Pixis::CLI::SetupDB;
use Moose;
use DateTime;
use Digest::SHA1 qw(sha1_hex);
use Pixis::Schema::Master;
use namespace::clean -except => qw(meta);

with 'MooseX::Getopt';

has 'dsn' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has 'username' => (
    is => 'rw',
    isa => 'Str',
);

has 'password' => (
    is => 'rw',
    isa => 'Str',
);

has 'drop' => (
    is => 'rw',
    isa => 'Bool',
    default => 0
);

__PACKAGE__->meta->make_immutable;

sub run {
    my $self = shift;
    my $options = { RaiseError => 1, AutoCommit => 1 };
    if ($self->dsn =~ /^dbi:mysql:/i) {
        $options->{on_connect_do} = [
            'SET sql_mode = "STRICT_TRANS_TABLES"',
            'SET NAMES utf8',
        ];
    }
    my $schema = Pixis::Schema::Master->connection(
        $self->dsn,
        $self->username,
        $self->password,
        $options,
    );
    $schema->deploy({
        quote_field_names => 0,
        add_drop_table => $self->drop
    });

    # remove these known tables, and rearrange them
    my @sources = grep { !/ProfileType$/ } $schema->sources;
    unshift @sources, 'ProfileType';

    foreach my $source (@sources) {
        my $class = $schema->class($source);
        if (my $code = $class->can('populate_initial_data')) {
            eval {
                $code->($class, $schema);
            };
            if ($@) {
                print STDERR "Failed to load data for $source\n   $@\n";
            }
        }
    }
    return ();
}

1;