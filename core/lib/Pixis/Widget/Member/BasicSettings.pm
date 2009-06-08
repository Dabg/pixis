package Pixis::Widget::Member::BasicSettings;
use Moose;
use namespace::clean -except => qw(meta);

with 'Pixis::Widget';

sub _build_template {
    return Path::Class::File->new('widget', 'member', 'basic_settings.tt');
}

around run => sub {
    my ($next, $self, $args) = @_;

    my $h = $next->($self, $args);

    my $form = $args->{context}->model('FormFu')->load('member/basic_settings');
    $form->model->default_values(
        Pixis::Registry->get(api => 'Member')->find( $args->{user}->id ) );

    $h->{form} = $form;

    return $h;
};

1;

