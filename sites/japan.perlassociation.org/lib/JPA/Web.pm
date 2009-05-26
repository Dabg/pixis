package JPA::Web;
use Moose;
use Catalyst;
BEGIN { extends 'Pixis::Web' }

__PACKAGE__->setup_config();
__PACKAGE__->setup();

1;
