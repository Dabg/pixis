use Test::More;

if (-d '../.git' || -d '.git' || $ENV{TEST_AUTHOR}) {
    eval {
        require Test::Perl::Critic;
        require File::Find::Rule;
    };
    if($@) {
        plan skip_all => "Test requires Test::Perl::Critic";
    } else {
        my $rcfile = File::Spec->catfile( 't', 'perlcriticrc' );
        Test::Perl::Critic->import(-profile => $rcfile);

        my @files = File::Find::Rule->file->name('*.pm')->in("blib");
        plan(tests => scalar @files);
        critic_ok($_) for @files;
    }
}