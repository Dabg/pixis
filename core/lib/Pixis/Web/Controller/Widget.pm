package Pixis::Web::Controller::Widget;
use Moose;
use namespace::clean -except => qw(meta);

BEGIN { extends 'Catalyst::Controller' }

sub load_widget :Chained('/') :PathPart('widget') :CaptureArgs(1) {
    my ($self, $c, $type) = @_;
    $c->stash->{widget} = ucfirst $type;
    $c->stash->{page} ||= $c->config->{page};
    return ();
}

sub run :Chained('load_widget') :PathPart('') :Args {
    my ($self, $c) = @_;

    my $widget = $c->model('Widget')->load($c->stash->{widget});
    my $args   = $widget->run({
        user => $c->user,
        request => $c->req,
        referer => $c->req->param('referer'),
        page => $c->stash->{page},
    });
    $c->res->body(
        $c->view('TT')->render($c, $args->{template}, { args => $args }) );
    return ();
}

1;
