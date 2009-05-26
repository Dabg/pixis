
package Pixis::Plugin::JPA;
use Moose;
use namespace::clean -except => qw(meta);

with 'Pixis::Plugin';

#has '+extra_api' => (
#    default => sub { +[ qw(JPAMember) ] }
#);

after 'register' => sub {
    my $registry = Pixis::Registry->instance;
    my $c = $registry->get(pixis => 'web');

    $c->controller('Signup')->add_step('/signup/contd') ;

    my $left = $c->model('Widget')->load('LeftNavigation');

    $left->logo_set( id  => 'logo' );
    $left->logo_set( uri => '/' );
    $left->logo_set( image_uri => '/static/jpa/img/logo.jpg');
    $left->logo_set( alt => 'Japan Perl Association' );
        

    $left->submenu_add(
        { uri => "/signup",    text => "会員登録" },
        { uri => "/sponsors",  text => "賛同企業・会員" },
        { uri => "/poweredby", text => "Powered By" },
    );

    $left->item_add(
        { id => 'jpa', uri => '/', text => 'JPAホーム' },
        { id => "news", uri => '/news',  text => "JPA News" },
        { id => "services", text => "JPA Services", uri => "/service" },
        { id => "blog", uri => "http://blog.perlassociation.org", text => "運営ブログ" },
        { id => 'wiki', uri => 'http://wiki.perlassociation.org', text => 'JPA Wiki' },
    );
};

__PACKAGE__->meta->make_immutable;

1;