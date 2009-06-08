package Pixis::Widget::Member::ProfileSettings;
use Moose;
use namespace::clean -except => qw(meta);

with 'Pixis::Widget';

sub _build_template {
    return Path::Class::File->new('widget', 'member', 'profile_settings.tt');
}

around run => sub {
    my ($next, $self, $args) = @_;

    my $data = $next->($self, $args);

    my ($profile) = Pixis::Registry->get(api => 'Profile')->load_from_member(
        {
            member_id => $args->{user}->id,
            type      => 'public'
        }
    );
    $data->{profile} = $profile;
    return $data;
};

1;

