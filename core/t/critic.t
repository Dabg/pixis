use Test::More;

if (-d '../.git' || -d '.git' || $ENV{TEST_AUTHOR}) {
    eval {
        require Test::Perl::Critic;
    };
    if($@) {
        plan skip_all => "Test requires Test::Perl::Critic";
    } else {
        my $rcfile = File::Spec->catfile( 't', 'perlcriticrc' );
        Test::Perl::Critic->import(-profile => $rcfile);
        all_critic_ok();
    }
}