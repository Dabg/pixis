package JPA::Web::Controller::Root;
use Moose;

BEGIN { extends 'Pixis::Web::Controller::Root' }

sub index :Path :Args {}
sub board :Local :Args {}
sub poweredby :Local :Args {}
sub sponsors :Local :Args {}

1;