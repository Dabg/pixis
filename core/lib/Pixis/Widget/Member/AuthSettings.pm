package Pixis::Widget::Member::AuthSettings;
use Moose;
use namespace::clean -except => qw(meta);

with 'Pixis::Widget';

sub _build_template {
    return Path::Class::File->new('widget', 'member', 'auth_settings.tt');
}

around run => sub {
    my ($next, $self, $args) = @_;

    my $h;
    if ($args->{user}->email =~ /oauth\.dummy$/) {
        $h = { widget_disabled => 1 };
    } else {
        $h = $next->($self, $args);

        my $form = $args->{context}->model('FormFu')->load('member/auth_settings');
        $form->model->default_values(
            Pixis::Registry->get(api => 'Member')->find( $args->{user}->id ) );

        $h->{form} = $form;
    }

    return $h;
};

1;

