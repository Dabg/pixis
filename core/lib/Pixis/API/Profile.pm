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
    my %args = (
        bio => $form->param('bio') || undef,
        member_id => $user->id,
    );
    if ( $form->param('id') ) {
        $args{id} = $form->param('id');
    }

    my $profile = $rs->update_or_create(\%args);
    return $profile;
}

1;
