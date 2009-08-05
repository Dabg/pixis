
package Pixis::API::Member;
use Moose;
use Pixis::Registry;
use Digest::SHA1();
use namespace::clean -except => qw(meta);

with 'Pixis::API::Base::DBIC';

around delete => sub {
    my ($next, $self, $id) = @_;

    my $schema = Pixis::Registry->get(schema => 'master');
    my $guard  = $schema->txn_scope_guard();
    my $rs = $schema->resultset('MemberToProfile')->search(
        {
            member_id => $id
        }
    );
    my $link = $rs->single;
    if ($link) {
        $schema->resultset( $link->moniker )->search(
            {
                id => $link->profile_id,
            }
        )->delete;
    }
    $rs->delete;

    my $obj;
    {
        local $self->{resultset_constraints} = {};
        $obj = $self->find($id);
    }
    if ($obj) {
        my $email = $obj->email;
        $next->($self, $id);

        # This should really be an API...
        Pixis::Registry->get(schema => 'master')
            ->resultset('MemberAuth')
            ->search(
                { member_id => $obj->id },
        )->delete;
        Pixis::Registry->get(api => 'MemberRelationship')->break_all($id);
    }
    $guard->commit;
};

sub _build_resultset_constraints {
    return +{ is_active => 1 }
}

sub load_from_email {
    my ($self, $email) = @_;
    my $member = $self->resultset()->search(
        { email => $email },
        { select => [ qw(id) ] }
    )->first;
    return $member ? $self->find($member->id) : ();
}

sub load_from_profile {
    my( $self, $profile_id ) = @_;

    my $profile = Pixis::Registry->get( api => 'Profile' )
        ->find($profile_id);

    return unless $profile;

    return $self->find( $profile->member_id );
}

around create => sub {
    my ($next, $self, $args) = @_;

    my $schema = Pixis::Registry->get(schema => 'master');

    my $guard = $schema->txn_scope_guard();
    $args->{is_active} = 0;

    my $member = $next->($self, $args);

    # Create an auth
    $schema->resultset('MemberAuth')->create({
        member_id => $member->id,
        auth_type => 'password',
        auth_data => Digest::SHA1::sha1_hex(delete $args->{password}),
    });

    $guard->commit;
    return $member;
};

# returns member with activation_token
sub forgot_password {
    my ($self, $args) = @_;

    $args->{email} or die 'no email';
    my $member = $self->load_from_email($args->{email}) or return;
    $member->is_active or return;

    my $schema = Pixis::Registry->get(schema => 'master');

    my $guard = $schema->txn_scope_guard();

    $member->activation_token(Digest::SHA1::sha1_hex(time, rand, $$, {}, $self->cache_prefix, $member->id));
    $member->update;
    # delete the cache, just in case
    $self->cache_del([ $self->cache_prefix, $member->id ]);

    $guard->commit;

    return $self->find($member->id);
}

# returns member matching email and activation_token
sub reset_password {
    my ($self, $args) = @_;

    if (! $args->{email} || ! $args->{token}) {
        return ();
    }

    my $member = $self->load_from_email($args->{email}) or return;
    $member->is_active or return;
    $member->activation_token eq $args->{token} or return;

    my $schema = Pixis::Registry->get(schema => 'master');
    my $guard  = $schema->txn_scope_guard;

    $member->activation_token(undef);
    $member->update;
    # delete the cache, just in case
    $self->cache_del([ $self->cache_prefix, $member->id ]);

    $guard->commit;

    return $self->find($member->id);
}

sub activate {
    my ($self, $args) = @_;

    $args->{token} or die "no token";
    $args->{email} or die "no email";

    my $schema = Pixis::Registry->get(schema => 'master');

    local $self->{resultset_constraints} = {};
    my $member = $self->resultset()->search({
        is_active => 0,
        activation_token => $args->{token},
        email => $args->{email},
    })->single;

    if (! $member) {
        return ();
    }

    my $guard  = $schema->txn_scope_guard;
    $member->activation_token(undef);
    $member->is_active(1);
    $member->update;
    # delete the cache, just in case
    $self->cache_del([ $self->cache_prefix, $member->id ]);

    $guard->commit;

    return $self->find($member->id);
}

sub search_members {
    my ($self, $args) = @_;

    my %where;
    foreach my $param qw(name nickname email) {
        next unless exists $args->{$param};
        my $value = $args->{$param};

        $value =~ s/%/%%/g;
        $where{$param} = { -like => sprintf('%%%s%%', $value) };
    }

    my $schema = Pixis::Registry->get(schema => 'master');
    my $rs     = $self->resultset();
    my @ids = map { $_->id } $rs->search(
        {
            -or => \%where
        },
        {
            select => [ qw(id) ],
        }
    );
    return $self->load_multi(@ids);
}

sub load_following {
    my ($self, $id) = @_;

    my $cache_key = [ 'member', 'following', $id ];
    my $ids = $self->cache_get($cache_key);

    my $schema = Pixis::Registry->get(schema => 'master');
    my $rs     = $schema->resultset('MemberRelationship');
    if (! $ids) {
        $ids = [ map { $_->to_id } $rs->search(
            {
                from_id => $id,
            },
            {
                select => [ qw(to_id) ],
            }
        ) ];
        $self->cache_set($cache_key, $ids, 600);
    }

    return $self->load_multi(@$ids);
}

sub load_followers {
    my ($self, $id) = @_;

    my $cache_key = [ 'member', 'followers', $id ];
    my $ids = $self->cache_get($cache_key);

    my $schema = Pixis::Registry->get(schema => 'master');
    my $rs     = $schema->resultset('MemberRelationship');
    if (! $ids) {
        $ids = [ map { $_->from_id } $rs->search(
            {
                to_id => $id,
            },
            {
                select => [ qw(from_id) ],
            }
        ) ];
        $self->cache_set($cache_key, $ids, 600);
    }

    return $self->load_multi(@$ids);
}

sub follow {
    my ($self, $from, $to)  = @_;
    $self->cache_del([ 'member', 'following', $from ]);
    $self->cache_del([ 'member', 'followers', $to ]);
    return Pixis::Registry->get(api => 'MemberRelationship')->follow($from, $to);
}

sub unfollow {
    my ($self, $from, $to)  = @_;
    $self->cache_del([ 'member', 'following', $from ]);
    $self->cache_del([ 'member', 'followers', $to ]);
    return Pixis::Registry->get(api => 'MemberRelationship')->unfollow($from, $to);
}

sub soft_delete {
    my ($self, $id) = @_;

    my $schema = Pixis::Registry->get(schema => 'master');
    my $guard  = $schema->txn_scope_guard;

    # invalidate followings, followers
    Pixis::Registry->get(api => 'MemberRelationship')->break_all($id);

    $guard->commit;

    return $self->resultset->search(
        {
            id => $id
        }
    )->update(
        {
            is_active => 0 
        }
    );
}

sub load_recent_activity {
    my ($self, $args) = @_;

    my $schema = Pixis::Registry->get(schema => 'master');
    my @list = $schema->resultset('ActivityGithub')->search(
        undef,
        { rows => 10, order_by => 'activity_on DESC' }
    );
    return wantarray ? @list : [@list];
}

sub create_email_confirm {
    my ($self, $args) = @_;

    return Pixis::Registry->get(schema => 'Master')->resultset('MemberEmailConfirm')->find_or_create(
        {
            member_id => $args->{member_id},
            email     => $args->{email},
        },
        {
            key => 'unique_combo',
        }
    );
}

sub load_email_confirm {
    my ($self, $args) = @_;

    return Pixis::Registry->get(schema => 'Master')->resultset('MemberEmailConfirm')->search(
        {
            member_id => $args->{member_id},
            email     => $args->{email},
            token     => $args->{token},
        },
    )->single;
}

__PACKAGE__->meta->make_immutable;

1;
