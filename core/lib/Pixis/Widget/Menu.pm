package Pixis::Widget::Menu;
use Moose;
use namespace::clean -except => qw(meta);

with 'Pixis::Widget';

__PACKAGE__->meta->make_immutable;

1;