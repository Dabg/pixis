package Pixis::API::MessageRecipient;
use Moose;
use Pixis::Registry;
use namespace::clean -except => qw(meta);

with 'Pixis::API::Base::DBIC';

sub set_read {
    my ( $self, $message, $member ) = @_;
    my $found = $self->search_with_member($message, $member);
    $found->update({opened_on => \'NOW()'}) if $found;
    return;
}

sub search_with_member {
    my ( $self, $message, $member ) = @_;
    my @profile_id = map {$_->id } Pixis::Registry->get(api => 'Profile')
        ->load_from_member({member_id => $member->id});
    my ($found) = Pixis::Registry->get(api => 'MessageRecipient')
        ->search(
            {
                message_id => $message->id,
                to_profile_id => \@profile_id,
            }
        );
    return $found;
}

__PACKAGE__->meta->make_immutable;

1;
