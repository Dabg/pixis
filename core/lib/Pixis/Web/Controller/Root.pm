package Pixis::Web::Controller::Root;
use Moose;

BEGIN { extends 'Catalyst::Controller' };

__PACKAGE__->config->{namespace} = '';

has site_index => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_site_index',
);

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
}

sub default :Path {
    Pixis::Web::Exception::FileNotFound->throw();
}

sub error :Private {
    my ($self, $c, $comment) = @_;
    Pixis::Web::Exception->new(message => $comment);
}

sub end : ActionClass('RenderView') {}

1;
