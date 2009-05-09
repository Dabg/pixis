package Pixis::API::Profile;
use Moose;
use Pixis::Registry;
use namespace::clean -except => qw(meta);

with 'Pixis::API::Base::DBIC';

__PACKAGE__->meta->make_immutable;

sub update_from_form {
    my ($self, $user, $form) = @_;
    my $schema = Pixis::Registry->get(schema => 'master');
    my $rs = $schema->resultset('Profile');
    my $profile = $rs->update_or_create(
        {
            ($form->param('id') ? (id => $form->param('id')) : () ),
            bio => $form->param('bio'),
            member_id => $user->id,
        }
    );
    return $profile;
}

1;
