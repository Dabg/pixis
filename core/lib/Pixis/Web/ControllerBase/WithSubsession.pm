package Pixis::Web::ControllerBase::WithSubsession;
use Moose::Role;
use namespace::clean -except => qw(meta);

has subsession_expires => (
    is => 'ro',
    isa => 'Int',
    default => 900
);

sub new_subsession {
    my ($self, $c, $value) = @_;

    if (! $value || ref $value ne 'HASH') {
        die "subsession must be a hash";
    }

    my $subsession = $c->generate_session_id;
    $self->set_subsession($c, $subsession, $value);
    return $subsession;
}

sub get_subsession {
    my ($self, $c, $subsession) = @_;
    my $container = $c->session->{__subsessions}->{$subsession};
    return $container ? $container->{data} : ();
}

sub set_subsession {
    my ($self, $c, $subsession, $value) = @_;

    my $x = $c->session->{__subsessions};
    my $time = time();
    foreach my $k (keys %$x) {
        my $v = $x->{$k};
        if (!defined $v->{__subsession_expires} || $v->{__subsession_expires} <= $time) {
            delete $x->{$k};
        }
    }

    my $item = {
        expires => time() + $self->subsession_expires,
        data    => $value
    };

    return $c->session->{__subsessions}->{$subsession} = $item;
}

sub delete_subsession {
    my ($self, $c, $subsession, $value) = @_;
    return delete $c->session->{__subsessions}->{$subsession};
}

1;

