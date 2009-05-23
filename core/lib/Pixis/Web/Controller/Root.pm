package Pixis::Web::Controller::Root;
use Moose;
use namespace::clean -except => qw(meta);

BEGIN { extends 'Catalyst::Controller' };

__PACKAGE__->config->{namespace} = '';

has site_index => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_site_index',
);

sub begin :Private {
    my ($self, $c) = (@_);
    $c->stash->{page} = $c->config->{page};
}

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    if ($self->has_site_index) {
        my $index = $self->site_index();
        # user has define some sort of custom index
        $c->res->redirect($c->uri_for($index));
    }

    if ($c->user_exists) {
        $c->res->redirect($c->uri_for('/member/home'));
        $c->finalize();
    }
    return ();
}

sub default :Path {
    Pixis::Web::Exception::FileNotFound->throw();
    return ();
}

sub error :Private {
    my ($self, $c, $comment) = @_;
    Pixis::Web::Exception->new(message => $comment);
    return ();
}

sub end : ActionClass('RenderView') {}

1;
