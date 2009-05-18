package Pixis::Web::Controller::Widget;
use Moose;

BEGIN { extends 'Catalyst::Controller' }

sub load_widget :Chained('/') :PathPart('widget') :CaptureArgs(1) {
    my ($self, $c, $type) = @_;
    $c->stash->{widget} = $type;
}

sub run :Chained('load_widget') :PathPart('') :Args {}

1;