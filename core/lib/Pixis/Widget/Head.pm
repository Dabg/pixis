package Pixis::Widget::Head;
use Moose;
use namespace::clean -except => qw(meta);

with 'Pixis::Widget';

=head1 NAME

Pixis::Widget::Header

=head1 DESCRIPTION

Widget to deliver the <head> of an HTML page.

=head1 METHODS

=cut

before 'run' => sub {
    
};

1;
