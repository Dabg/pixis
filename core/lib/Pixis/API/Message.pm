package Pixis::API::Message;
use Moose;
use Pixis::Registry;
use namespace::clean -exept => qw(meta);

with 'Pixis::API::Base::DBIC';

around create => sub {
    my ( $next, $self, $args ) = @_;

    local $Data::Dumper::Terse    = 1;
    local $Data::Dumper::Sortkeys = 1;
    local $Data::Dumper::Indent   = 1;

    my %args = (
        id => Digest::SHA1::sha1_hex($args, {}, time(), $$, rand()),
        from_profile_id => $args->{from}->id,
        subject        => $args->{subject},
        body           => $args->{body},
    );

    my $message = $next->($self, \%args);
    $message->add_to_recipients(
        {
            to_profile_id => $args->{to}->id
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

sub opponent {
    my ( $self, $message, $member ) = @_;
    my $id;
    $id = $message->from_profile_id if $self->is_in_message($message, $member);
#    $id = $message->to_profile_id if $self->is_out_message($message, $member);
    $id or return;
    return Pixis::Registry->get(schema => 'master')
        ->resultset('Profile')
        ->find($id);
}

sub is_out_message {
    my ( $self, $message, $member ) = @_;
    return $message->from_profile->member->id == $member->id;
}

sub is_in_message {
    my ( $self, $message, $member ) = @_;
    my @profile_id = map {$_->id } Pixis::Registry->get(api => 'Profile')
        ->load_from_member({member_id => $member->id});
    my $found = Pixis::Registry->get(api => 'MessageRecipient')
        ->search(
            {
                message_id => $message->id,
                to_profile_id => \@profile_id,
            }
        );
    return scalar @$found ? 1 : 0;
}

sub is_viewable {
    my ($self, $message, $member ) = @_;
    return $self->is_out_message($message, $member) || $self->is_in_message($message, $member);
}

__PACKAGE__->meta->make_immutable;

1;
