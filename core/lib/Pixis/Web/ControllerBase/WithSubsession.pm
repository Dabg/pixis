package Pixis::Web::ControllerBase::WithSubsession;
use Moose;
use namespace::clean -except => qw(meta);

BEGIN { extends 'Catalyst::Controller' }

sub new_subsession {
    my ($self, $c, $value) = @_;
    my $subsession = $c->generate_session_id;
    $self->set_subsession($c, $subsession, $value);
    return $subsession;
}

sub get_subsession {
    my ($self, $c, $subsession) = @_;
    return $c->session->{__subsessions}->{$subsession} || {};
}

sub set_subsession {
    my ($self, $c, $subsession, $value) = @_;
    return $c->session->{__subsessions}->{$subsession} = $value;
}

sub delete_subsession {
    my ($self, $c, $subsession, $value) = @_;
    return delete $c->session->{__subsessions}->{$subsession};
}

__PACKAGE__->meta->make_immutable;

1;

