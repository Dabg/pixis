package Test::Pixis::API::Member;
use Moose;
use Digest::SHA1 ();

BEGIN {
    extends 'Test::Pixis::Fixture';
    with 
        'Test::Pixis::Setup::Basic',
        'Test::Pixis::Setup::Schema',
        'Test::Pixis::Setup::Mechanize',
        'Test::Pixis::Setup::Memcached',
    ;
}

sub setup :Test :Plan(3) {
    my $self = shift;

    my $registry = Pixis::Registry->instance();

    $registry->set(schema => 'master', $self->schema);
    $registry->set(api => 'memberrelationship' => $self->api('MemberRelationship'));
    $registry->set(api => 'memberauth' => $self->api('MemberAuth'));
    $registry->set(api => 'member' => $self->api('Member'));
    $registry->set(api => 'profile' => $self->api('Profile'));

    # make sure these don't exist at cleanup
    lives_ok {
        my $api = Pixis::Registry->get(api => 'member');
        local $api->{resultset_constraints} = {};
        my $members = $self->members;
        my @members = $api->search({ email => { -in => [
            $members->[0]->{email},
            $members->[1]->{email}
        ] } });
        $api->delete($_->id) for @members;


        ok( ! $api->load_from_email($members->[0]->{email}), "properly deleted user 1");
        ok( ! $api->load_from_email($members->[1]->{email}), "properly deleted user 2");
    } "member deletion (at setup)";
}

sub expected_load_failure {
    my ($self, $which, $suite) = @_;
    my $api = Pixis::Registry->get(api => 'member');
    my $data = $self->members->[$which];

    my $found = $api->find($data->{id});
    ok(! $found, "$suite non active member should not be loaded by pk");
    $found = undef;
    $found = $api->load_from_email($data->{email});
    ok(! $found, "$suite non active member should not be loaded by email");

    my @list = $api->search_members({
        email => $data->{email}
    });
    ok( !@list, "$suite non active member should not be loaded from search");

    my @auth = Pixis::Registry->get(api => 'MemberAuth')->load_auth({
        email => $data->{email},
        auth_type => 'password',
    });
    ok( !@auth, "$suite non active member should not have their auth loaded");
}

sub create_member :Test :Plan(8) {
    my ($self, $which) = @_;

    lives_ok {
        my $api = Pixis::Registry->get(api => 'member');
        my $data = { %{$self->members->[$which]} }; # copy
        my $profiles = delete $data->{profiles} || [];
        my $member = $api->create($data);
        ok($member, "member creation returns something");
        isa_ok($member, "Pixis::Schema::Master::Result::Member", "object is a proper DBIx::Class object");
        $data->{id} = $member->id;

        # now create profiles
        my $profile_api = Pixis::Registry->get(api => 'Profile');
        foreach my $profile (@$profiles) {
            my %args = %$profile;
            $args{member_id} = $member->id;
            $profile_api->create_type(delete $args{type}, \%args);
        }
    } "member creation lives";

    # first time around is_active is false, so all these tests should fail
    lives_ok {
        $self->expected_load_failure($which, "(Just Created)");
    } "member load (non-active)";
}

sub activate_member :Test :Plan(5) {
    my ($self, $which) = @_;

    lives_ok {
        my $api = Pixis::Registry->get(api => 'member');
        my $data = $self->members->[$which];
        $api->activate({
            email => $data->{email},
            token => 'dummy',
        });
        $self->expected_load_failure($which, "(Bogus Activation)");

        $api->activate({
            email => $data->{email},
            token => $data->{activation_token},
        });
    } "member activation";
}

sub check_active_member :Test :Plan(7) {
    my ($self, $which) = @_;

    lives_ok {
        my $api = Pixis::Registry->get(api => 'member');

        my $data = $self->members->[$which];
        my $found = $api->find($data->{id});

        if (ok($found, "member loaded by primary key ok")) {
            is($found->email, $data->{email}, "email match");
        } else {
            fail("email match skipped (no member loaded)");
        }

        $found = undef;
        $found = $api->load_from_email($data->{email});
        if (ok($found, "member loaded by email ok")) {
            is($found->id, $data->{id}, "id match");
        } else {
            fail("id match skipped (no member loaded)");
        }

        my @list = $api->search_members({
            email => $data->{email}
        });
        if (is(scalar @list, 1, "search member turns up 1 result")) {
            is($list[0]->email, $data->{email}, "email matches");
        } else {
            fail("nothing turned up from search");
        }
    } "member load";
}

sub check_followers :Test :Plan(4) {
    my $self = shift;
    lives_ok {
        my $api = Pixis::Registry->get(api => 'member');

        $api->follow($self->members->[0]->{id}, $self->members->[1]->{id});

        my @followers = $api->load_followers($self->members->[1]->{id});
        is (scalar(@followers), 1, "people following $self->members->[1]->{id}");
        if (! is ($followers[0]->id, $self->members->[0]->{id}, "member 1 is following member 2")) {
            diag( "got followers: ", explain(@followers));
        }
        my @following = $api->load_following($self->members->[0]->{id});
        is (scalar(@followers), 1, "should have 1 person following $self->members->[1]->{id} (got " . scalar @followers . ")");
        
    } "check followers with no exception";
}

sub delete_member :Test :Plan(3) {
    my ($self, $which) = @_;

    lives_ok {
        my $api = Pixis::Registry->get(api => 'member');
        my $member = $self->get_member($which);
        $api->delete($member->id);

        my $found = $api->find($member->id);
        ok( !$found);

        $found = $api->load_from_email($member->email);
        ok( ! $found);
    } "member deletion (at the end)";
}

__PACKAGE__->meta->make_immutable();
