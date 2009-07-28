package Pixis::API::Message;
use Moose;
use Pixis::Registry;
use namespace::clean -exept => qw(meta);

with 'Pixis::API::Base::DBIC';

around create => sub {
    my ( $next, $self, $args ) = @_;

    my ($from, $to) = ( $args->{from}, $args->{to} );
    if (ref $to ne 'ARRAY') {
       $to = [ $to ];
    }

    foreach my $i (0..$#{$to}) {
        if (! blessed $to->[$i]) {
            $to->[$i] = Pixis::Registry->get(api => 'Profile')->find($to->[$i]) or
                confess "Could not find recipient by ID '$to->[$i]";
        }
    }

    if (! blessed $from) {
        $from = Pixis::Registry->get(api => 'Profile')->find($from) or
            confess "Could not find sender by ID $from";
    }

    my %args = (
        from_profile_id => $from->id,
        subject        => $args->{subject},
        body           => $args->{body},
        is_system_message => $args->{is_system_message} ? 1 : 0,
    );

    my $schema = Pixis::Registry->get(schema => 'master');
    my $guard  = $schema->txn_scope_guard();

    # XXX We should really cache this
    my $tag_api = Pixis::Registry->get(api => 'MessageTag');
    my $inbox   = $tag_api->find_tag('Inbox');
    my $sent    = $tag_api->find_tag('Sent');
    my $m2t   = $schema->resultset('MessageToTags');

    my $message = $next->($self, \%args);
    $m2t->create( { profile_id => $from->id, message_id => $message->id, tag_id => $sent->id });
    foreach my $to_profile (@$to)  {
        $m2t->create( { profile_id => $to_profile->id, message_id => $message->id, tag_id => $inbox->id });
        $message->add_to_recipients(
            {
                to_profile_id => $to_profile->id
            }
        );
    }


    $guard->commit;

    return $message;
};

sub load_from_profile {
    my ($self, $args) = @_;

    my $tag;
    if( my $tag_name = delete $args->{tag}) {
        # XXX We should really cache this
        $tag = Pixis::Registry->get(api => 'MessageTag')->find_tag($tag_name);
    } else {
        $tag = Pixis::Registry->get(api => 'MessageTag')->find($args->{tag_id});
    }

    if (! $tag) {
        confess "No tag provided!";
    }

    my $profile = Pixis::Registry->get(api => 'Profile')->find( $args->{profile_id} );

    my $schema = $self->schema;
    my @ids = map { $_->message_id } 
        $schema->resultset('MessageToTags')->search(
            {
                profile_id => $profile->id,
                tag_id => $tag->id,
            },
            {
                select => [ 'message_id' ]
            }
        )
    ;

    return $self->load_multi(@ids);
}

sub load_from_member {
    my ( $self, $args ) = @_;

    my $tag;
    if( my $tag_name = delete $args->{tag}) {
        # XXX We should really cache this
        $tag = Pixis::Registry->get(api => 'MessageTag')->find_tag($tag_name);
    } else {
        $tag = Pixis::Registry->get(api => 'MessageTag')->find($args->{tag_id});
    }

    if (! $tag) {
        confess "No tag provided!";
    }

    my @profile_id = map { $_->id } Pixis::Registry->get(api => 'Profile')
        ->load_from_member({member_id => $args->{member_id}});

    my $schema = $self->schema;
    my @ids = map { $_->message_id } 
        $schema->resultset('MessageToTags')->search(
            {
                profile_id => { -in => \@profile_id },
                tag_id => $tag->id,
            },
            {
                select => [ 'message_id' ]
            }
        )
    ;

    return $self->load_multi(@ids);
}

sub load_from_query {
    my ( $self, $args ) = @_;

    my $q = $args->{query} or confess "no query";
    my $tag = $args->{tag} or confess "no tag";
    my $member_id = $args->{member_id} or confess "no member_id";

    my @profiles = map { $_->id } Pixis::Registry->get(api => 'Profile')->load_from_member(
        {
            member_id => $member_id
        }
    );
    my $tag_id;
    $tag = Pixis::Registry->get(api => 'MessageTag')->find_tag($tag);
    if ($tag) {
        $tag_id = $tag->id;
    }
    

    my @ids = map { $_->id } $self->resultset()->search(
        {
            '-and' => [
                '-or' => [
                    { from_profile_id => { -in => \@profiles } },
                    { 'recipients.to_profile_id' => { -in => \@profiles } },
                ],
                # XXX - yawza! in the future, we should implement real
                # full text search for this.
                '-or' => [
                    { body      => { -like => '%'.$q.'%' } },
                    { subject   => { -like => '%'.$q.'%' } },
                ],
                { 'message_to_tags.tag_id' => $tag_id }
            ],
        },
        {
            select => [ qw(me.id) ],
            join   => [ 'recipients', 'message_to_tags' ],
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
