package JPA::Web::Controller::Service;
use base qw(Catalyst::Controller);

sub index :Index :Args(0) {}
sub training :Local :Args(0) {}

1;
