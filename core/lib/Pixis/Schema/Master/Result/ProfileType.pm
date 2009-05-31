package Pixis::Schema::Master::Result::ProfileType;
use Moose;
use DateTime;
use namespace::clean -except => qw(meta);

extends 'Pixis::Schema::Master::Result';

__PACKAGE__->load_components(
    "PK::Auto", "UTF8Columns", "TimeStamp", "Core");
__PACKAGE__->table("pixis_profile_type");
__PACKAGE__->add_columns(
    id => {
        data_type => 'INTEGER',
        is_auto_increment => 1,
        is_nullable => 0,
        size => 32,
    },
    name => {
        data_type => "VARCHAR",
        is_nullable => 0,
        size => 256
    },
    created_on => {
        data_type => "DATETIME",
        is_nullable => 0,
        set_on_create => 1,
    },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->utf8_columns(qw(name));
__PACKAGE__->has_many(profiles => 'Pixis::Schema::Master::Result::Profile' => 'profile_type_id');

sub populate_initial_data {
    my ($self, $schema) = @_;
    $schema->populate(
        ProfileType => [
            [qw(name)],
            ['public'],
            ['private'],
        ],
    );
    return;
}

1;
