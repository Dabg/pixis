package Pixis::API::Message;
use Moose;
use Pixis::Registry;
use namespace::clean -exept => qw(meta);

with 'Pixis::API::Base::DBIC';

around create => sub {
    my ( $next, $self, $args ) = @_;

    my ($from, $to) = ( $args->{from}, $args->{to} );
    if (! blessed $to) {
        $to = Pixis::Registry->get(api => 'Profile')->find($to) or
            confess "Could not find recipient by ID '$to";
    }
    if (! blessed $from) {
        $from = Pixis::Registry->get(api => 'Profile')->find($from) or
            confess "Could not find sender by ID $from";
    }

    my %args = (
        id => Digest::SHA1::sha1_hex($args, {}, time(), $$, rand()),
        from_profile_id => $from->id,
        subject        => $args->{subject},
        body           => $args->{body},
        is_system_message => $args->{is_system_message} ? 1 : 0,
    );

    my $message = $next->($self, \%args);
    $message->add_to_recipients(
        {
            to_profile_id => $to->id
        }
    );
    return $message;
};

*send = \&create;

sub load_sent_from_member {
    my ( $self, $args ) = @_;

    my @profile_id = map {$_->id } Pixis::Registry->get(api => 'Profile')
        ->load_from_member({member_id => $args->{member_id}});

    my @ids = map { $_->id } $self->resultset()->search(
        { from_profile_id => \@profile_id },
        {
            select => [ qw(id) ],
            order_by => 'created_on desc',
        }
    );
    return $self->load_multi(@ids);
}

sub load_sent_to_member {
    my ( $self, $args ) = @_;

    my @profile_id = map {$_->id} Pixis::Registry->get(api => 'Profile')
        ->load_from_member({member_id => $args->{member_id}});

    my @ids = map { $_->message_id } Pixis::Registry->get(api => 'MessageRecipient')
        ->search(
            {to_profile_id => \@profile_id}, 
            { order_by => 'id desc' }
        );
    return $self->load_multi(@ids);
}

sub load_from_query {
    my ( $self, $args ) = @_;

    my $member_id = $args->{member_id};
    my $q = $args->{query};

    my @ids = map { $_->id } $self->resultset()->search(
        {
            '-and' => [
                '-or' => [
                    { from_member_id => $member_id },
                    { to_member_id => $member_id },
                ],
                # XXX - yawza! in the future, we should implement real
                # full text search for this.
                '-or' => [
                    { body => { -like => '%'.$q.'%' } },
                    { subject => { -like => '%'.$q.'%' } },
                ],
            ],
        },
        {
            select => [ qw(id) ],
        }
    );
    return $self->load_multi(@ids);
}

sub is_viewable {
    my ($self, $message, $member ) = @_;

    my $profile_api = Pixis::Registry->get(api => 'Profile');

    my $from = $profile_api->find($message->from_profile_id);
    if ($from->member_id eq $member->id) {
        return 1;
    }

    foreach my $recipient ($message->recipients) {
        my $to = $profile_api->find($recipient->to_profile_id);
        if ($to->member_id eq $member->id) {
            return 1;
        }
    }
    return ();
}

__PACKAGE__->meta->make_immutable;

1;
