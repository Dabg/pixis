package Pixis::Widget::Member::EmailSettings;
use Moose;
use namespace::clean -except => qw(meta);

with 'Pixis::Widget';

sub _build_template {
    return Path::Class::File->new('widget', 'member', 'email_settings.tt');
}

around run => sub {
    my ($next, $self, $args) = @_;

    my $h = $next->($self, $args);

    my $form = $args->{context}->model('FormFu')->load('member/email_settings');
    $form->model->default_values( 
        Pixis::Registry->get(api => 'Member')->find($args->{user}->id) );
    $h->{form} = $form;

    return $h;
};

1;
