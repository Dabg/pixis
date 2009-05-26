#!/usr/bin/env perl

BEGIN {
    # if there's a .git directory two levels up, then we're running from
    # a repo
    use File::Spec;

    my $root_dir = File::Spec->catdir(File::Spec->updir, File::Spec->updir);
    my $git_dir  = File::Spec->catdir($root_dir, '.git');
    my $core_lib = File::Spec->catdir($root_dir, 'core', 'lib');
    if (-d $git_dir) {
        $ENV{PIXIS_LIB} ||= $core_lib;
    }

    if (-d $ENV{PIXIS_LIB}) {
        unshift @INC, $ENV{PIXIS_LIB};
    }

    $ENV{CATALYST_ENGINE} ||= 'HTTP';
    $ENV{CATALYST_SCRIPT_GEN} = 33;
    require Catalyst::Engine::HTTP;
}

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use FindBin;
use lib "$FindBin::Bin/../lib";

my $debug             = 0;
my $fork              = 0;
my $help              = 0;
my $host              = undef;
my $port              = $ENV{JPA_WEB_PORT} || $ENV{CATALYST_PORT} || 3000;
my $keepalive         = 0;
my $restart           = $ENV{JPA_WEB_RELOAD} || $ENV{CATALYST_RELOAD} || 0;
my $restart_delay     = 1;
my $restart_regex     = '(?:/|^)(?!\.#).+(?:\.yml$|\.yaml$|\.conf|\.pm|\.po)$';
my $restart_directory = undef;
my $follow_symlinks   = 0;
my $background        = 0;

my @argv = @ARGV;

GetOptions(
    'debug|d'             => \$debug,
    'fork|f'              => \$fork,
    'help|?'              => \$help,
    'host=s'              => \$host,
    'port=s'              => \$port,
    'keepalive|k'         => \$keepalive,
    'restart|r'           => \$restart,
    'restartdelay|rd=s'   => \$restart_delay,
    'restartregex|rr=s'   => \$restart_regex,
    'restartdirectory=s@' => \$restart_directory,
    'followsymlinks'      => \$follow_symlinks,
    'background'          => \$background,
);

pod2usage(1) if $help;

if ( $restart && $ENV{CATALYST_ENGINE} eq 'HTTP' ) {
    $ENV{CATALYST_ENGINE} = 'HTTP::Restarter';
}
if ( $debug ) {
    $ENV{CATALYST_DEBUG} = 1;
}

# This is require instead of use so that the above environment
# variables can be set at runtime.
require JPA::Web;
JPA::Web->run( $port, $host, {
    argv              => \@argv,
    'fork'            => $fork,
    keepalive         => $keepalive,
    restart           => $restart,
    restart_delay     => $restart_delay,
    restart_regex     => qr/$restart_regex/,
    restart_directory => $restart_directory,
    follow_symlinks   => $follow_symlinks,
    background        => $background,
} );

1;

=head1 NAME

pixis_web_server.pl - Catalyst Testserver

=head1 SYNOPSIS

pixis_web_server.pl [options]

 Options:
   -d -debug          force debug mode
   -f -fork           handle each request in a new process
                      (defaults to false)
   -? -help           display this help and exits
      -host           host (defaults to all)
   -p -port           port (defaults to 3000)
   -k -keepalive      enable keep-alive connections
   -r -restart        restart when files get modified
                      (defaults to false)
   -rd -restartdelay  delay between file checks
   -rr -restartregex  regex match files that trigger
                      a restart when modified
                      (defaults to '\.yml$|\.yaml$|\.conf|\.pm$')
   -restartdirectory  the directory to search for
                      modified files, can be set mulitple times
                      (defaults to '[SCRIPT_DIR]/..')
   -follow_symlinks   follow symlinks in search directories
                      (defaults to false. this is a no-op on Win32)
   -background        run the process in the background
 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Run a Catalyst Testserver for this application.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
