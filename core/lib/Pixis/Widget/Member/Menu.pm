package Pixis::Widget::Member::Menu;
use Moose;
use namespace::clean -except => qw(clean);

with 'Pixis::Widget';

sub _build_tempalte {
    return Path::Class::File->new("widget", "member", "menu.tt");
}

1;