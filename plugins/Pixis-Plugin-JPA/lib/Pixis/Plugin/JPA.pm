
package Pixis::Plugin::JPA;
use Moose;
use namespace::clean -except => qw(meta);

with 'Pixis::Plugin';

has '+extra_api' => (
    default => sub { +[ qw(JPAMember) ] }
);

after 'register' => sub {
    my $registry = Pixis::Registry->instance;
    my $c = $registry->get(pixis => 'web');

    $c->controller('Signup')->add_step('/jpa/signup/contd') ;
};

__PACKAGE__->meta->make_immutable;

1;