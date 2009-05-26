package JPA::Web::Controller::Root;
use Moose;

BEGIN { extends 'Pixis::Web::Controller::Root' }

sub index :Path :Args {}
sub board :Local :Args {}

1;