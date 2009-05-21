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
        from_member_id => $args->{from}->id,
        to_member_id   => $args->{to}->id,
        subject        => $args->{subject},
        body           => $args->{body},
        created_on     => \'NOW()',
    );

    return $next->($self, \%args)
};
*send = \&create;

sub load_sent_from_member {
    my ( $self, $args ) = @_;

    my $member_id = $args->{member_id};

    my @ids = map { $_->id } $self->resultset()->search(
        { from_member_id => $member_id },
        {
            select => [ qw(id) ],
        }
    );
    return $self->load_multi(@ids);
}

sub load_sent_to_member {
    my ( $self, $args ) = @_;

    my $member_id = $args->{member_id};

    my @ids = map { $_->id } $self->resultset()->search(
        { to_member_id => $member_id },
        {
            select => [ qw(id) ],
        }
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
    $id = $message->from_member_id if $self->is_in_message($message, $member);
    $id = $message->to_member_id if $self->is_out_message($message, $member);
    $id or return;
    return Pixis::Registry->get(schema => 'master')
        ->resultset('Member')
        ->find($id);
}

sub is_out_message {
    my ( $self, $message, $member ) = @_;
    return $message->from_member_id == $member->id;
}

sub is_in_message {
    my ( $self, $message, $member ) = @_;
    return $message->to_member_id == $member->id;
}

__PACKAGE__->meta->make_immutable;

1;
