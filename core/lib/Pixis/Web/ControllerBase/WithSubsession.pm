package Pixis::Web::ControllerBase::WithSubsession;
use Moose::Role;
use namespace::clean -except => qw(meta);

has strict_subsession => (
    is => 'ro',
    isa => 'Bool'
    required => 1,
    default => 1
);

has subsession_expires => (
    is => 'ro',
    isa => 'Int',
    required => 1,
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
    if ($self->strict_subsession) {
        Pixis::Web::Exception->throw(message => "指定されたサブセッション$subsessionが存在しません");
    }
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
        __subession_expires => time() + $self->subsession_expires,
        data    => $value
    };

    return $c->session->{__subsessions}->{$subsession} = $item;
}

sub delete_subsession {
    my ($self, $c, $subsession) = @_;
    return delete $c->session->{__subsessions}->{$subsession}->{data};
}

1;

__END__

=head1 NAME

Pixis::Web::ControllerBase::WithSubsession - Role to Give Your Controller Subsession 

=head1 SYNOPSIS

    package MyApp::Controller::Foo;
    use Moose;
    use namespace::clean -except => qw(meta);

    BEGIN {
        extends 'Pixis::Web::ControllerBase';
        with    'Pixis::Web::ControllerBase::WithSubsession';
    }

=head1 DECRIPTION

This role gives your controller the ability to manipulate subsessions.
You typically embed them in the URL:

    sub start_subsession :Local {
        my ($self, $c) = @_;

        my $data = { .... }; # some data that you want to store in the
                             # subsession, for later retrieval
        my $subsession = $self->new_subsession($c, $data);
        $c->res->redirect(
            $c->uri_for('/next_step', $subsession) );
    }

    sub next_step :Local :Args(1) {
        my ($self, $c, $subsession) = @_;

        my $data = $self->get_subsession($c, $subsession);
        ....
    }

=head1 METHODS

=head2 $session_id = new_subsession($c, $data)

=head2 $data = get_subsession($c, $session_id)

=head2 set_subsession($c, $data)

=head2 delete_subsession($c, $session_id)

=cut
