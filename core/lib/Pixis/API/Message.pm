package Pixis::API::Message;
use Moose;
use Pixis::Registry;
use namespace::clean -exept => qw(meta);

with 'Pixis::API::Base::DBIC';

sub send {
    my ( $self, $args ) = @_;
    my $message = $self->resultset()->create(
        {
            from_member_id => $args->{from}->id,
            to_member_id => $args->{to}->id,
            subject => $args->{subject},
            body => $args->{body},
            created_on => \'NOW()',
        }
    );
    return $message;
}

sub load_from_member {
    my ( $self, $member, $where ) = @_;

    $where ||= '';

    my @ids = map { $_->id } $self->resultset()->search(
        {
            '-and' => [
                '-or' => [
                    { from_member_id => $member->id },
                    { to_member_id => $member->id },
                ],
                '-or' => [
                    { body => { -like => '%'.$where.'%' } },
                    { subject => { -like => '%'.$where.'%' } },
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
