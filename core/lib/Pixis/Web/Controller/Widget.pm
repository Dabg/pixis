package Pixis::Web::Controller::Widget;
use Moose;

BEGIN { extends 'Catalyst::Controller' }

sub load_widget :Chained('/') :PathPart('widget') :CaptureArgs(1) {
    my ($self, $c, $type) = @_;
    $c->stash->{template} = "widget/$type.tt";
    $c->stash->{widget} = ucfirst $type;
}

sub run :Chained('load_widget') :PathPart('') :Args {
    my ($self, $c) = @_;
    $c->view('TT')->process($c, $c->stash->{template}, $c->stash);
}

1;