package Pixis::API::MessageTag;
use Moose;
use namespace::clean -except => qw(meta);

with 'Pixis::API::Base::DBIC';

sub find_tag {
    my ($self, $tag) = @_;

    my $schema = $self->schema;
    my $cache_key = [$self->cache_prefix, tag => $tag ];
    my $obj = $self->cache_get($cache_key);
    if ($obj) {
        $obj = $schema->thaw($obj);
    } else {
        $obj = $self->resultset->find({ tag => $tag });
        if ($obj) {
            $self->cache_set($cache_key, $schema->freeze($obj));
        }
    }
    return $obj;
}

1;
