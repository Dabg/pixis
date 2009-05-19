package Pixis::Web::Controller::Widget;
use Moose;

BEGIN { extends 'Catalyst::Controller' }

sub load_widget :Chained('/') :PathPart('widget') :CaptureArgs(1) {
    my ($self, $c, $type) = @_;
    $c->stash->{widget} = ucfirst $type;
}

sub run :Chained('load_widget') :PathPart('') :Args {
    my ($self, $c) = @_;

    my $widget = $c->model('Widget')->load($c->stash->{widget});
    my $args   = $widget->run({
        user => $c->user 
    });
    $c->res->body(
        $c->view('TT')->render($c, $args->{template}, $args) );
}

1;