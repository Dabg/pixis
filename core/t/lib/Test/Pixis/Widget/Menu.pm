package Test::Pixis::Widget::Menu;
use Moose;
use Template;
use Test::MockObject;
use URI;
BEGIN { extends 'Test::Pixis::Fixture' }

has widget => (is => 'ro', does => 'Pixis::Widget', lazy_build => 1);

sub _build_widget {
    Class::MOP::load_class("Pixis::Widget::Menu");
    return Pixis::Widget::Menu->new();
}

sub run : Test :Plan(2) {
    my $self = shift;
    my $h = $self->widget->run({
        request => Test::MockObject->new
            ->set_always( uri => URI->new('http://example.com') )
            ->set_always( param => undef )
    });
    isa_ok( $h, "HASH" );
    is($h->{template}, "widget/menu.tt", "args->{template}");
}

sub run_esi :Test :Plan(3) {
    my $self = shift;
    local $self->widget->{is_esi} = 1;
    local $self->widget->{query_params} = { is_logged_in => 1 };
    my $h = $self->widget->run({
        request => Test::MockObject->new
            ->set_always( uri => URI->new('http://example.com') )
            ->set_always( param => undef )
    });
    isa_ok( $h, "HASH" );
    is($h->{template}, "widget/menu.tt", "args->{template}");
    is($self->widget->esi_uri, "/widget/Menu?referer=http%3A%2F%2Fexample.com", "args->{esi_uri}");
}

sub run_from_tt :Test :Plan(1) {
    my $self = shift;
    my $template = Template->new(
        INCLUDE_PATH => 'root',
        PRE_PROCESS  => 'preprocess.tt',
        COMPILE_DIR  => 't/tt2',
    );

    my $out;
    my %args = (
        c => Test::MockObject->new
            ->set_always(
                model => Test::MockObject->new->set_always(
                    load => $self->widget
                )
            )
            ->set_always( plugins => () )
            ->set_always( session => {} )
            ->set_always( user    => undef )
            ->set_always( config  => { use_esi => 0 } )
            ->set_always( req     => Test::MockObject->new()
                ->set_always( uri => 'http://example.com' )
            )
        ,
        widget => 'Menu',
    );

    $template->process(\'[% run_widget(widget) %]', \%args, \$out) ||
        confess $template->error;

    like ($out, qr/^\s*<div id="menu">\s*<\/div>\s*$/);
}

__PACKAGE__->meta->make_immutable;

1;