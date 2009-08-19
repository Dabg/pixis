package Pixis::Web;
use Moose;
use Pixis;
use Pixis::Hacks;
use namespace::clean -except => qw(meta);

our $VERSION = '0.01';

sub import {
    my ($class, @args) = @_;

    # arguments are used to enable/disable plugins
    my %args;
    if (scalar @args == 1) {
        %args = %{$args[0]};
    } else {
        %args = (plugins => [@args]);
    }

    # first merge with default plugin set
    # then remove plugins that are specifically disabled
    $args{plugins} = [
        qw(
            Unicode
            Authentication
            Authorization::Roles
            ConfigLoader
            Data::Localize
            Session
            Session::Store::File
            Session::State::Cookie
            Session::State::URI
            Static::Simple
            +Pixis::Hub
            +Pixis::Catalyst::Core
            +Pixis::Catalyst::HandleException
            +Pixis::Catalyst::Plugins
            +Pixis::Catalyst::VirtualComponents
        ),
        @{ $args{plugins} || [] }
    ];

    if (my $plugins = $args{disable}) {
        my %disabled = map { ($_ => 1) } @{$args{plugins}};
        @{$args{plugins}} = grep { ! $disabled{ $_ } } @{$args{plugins}};
    }

    my $caller = caller(0);
    eval <<"    EOSUB";
        package $caller;
        # XXX Note to self: You /HAVE/ to say use Catalyst before doing anything
        # that depends on \$c->config->{home} (such as ->path_to()), as import()
        # is where the initialization gets triggered
        use Catalyst ( \@{ \$args{plugins} } );
        use Catalyst::Runtime '5.80';
    EOSUB
    die if $@;
}

my $caller = caller();
if ($caller eq 'main' || $ENV{HARNESS_ACTIVE}) {
    __PACKAGE__->setup() ;
}
    
1;

__END__

=head1 NAME

Pixis::Web - Extensible Catalyst Application Framework

=head1 SYNOPSIS

    package MyApp;
    use Pixis::Web;

    __PACKAGE__->config(
        # Specify any extra config variables here
    );
    __PACKAGE__->setup();

    1;

=head1 MODES OF OPERATION

You can either override Pixis::Web as described in the SYNOPSIS, or you can
write/include a set of plugins. Plugins allows you to add functionality without
having to change Pixis itself,, while extending Pixis::Web allows you to 
completely hijack how the application behaves.

=head1 EXTENDING Pixis::Web (OVERRIDING Pixis::Web)

When you extend Pixis::Web, the framework will generate matching components
from pixis in memory. For example, Pixis::Web::Controller::Auth will cause
Pixis::Web to automatically generate MyApp::Controller::Auth.

If, however, you provide your own MyApp::Controller::Auth, this will not be
the case. Pixis will happilly allow you to create a controller of the same name.
If you would like to extend the original controller, you may do so by
explicitly extending the original class:

    package MyApp::Controller::Auth;
    use Moose;
    use namespace::clean -except => qw(meta);

    BEGIN { extends 'Pixis::Web::Controller::Auth' }

=head1 WRITING PLUGINS

To write a plugin, create an object that implements 'register'. Use the following methods to add the appropriate 'stuff' for your plugin:

=over 4

=item add_tt_include_path

Adds include paths for your templates

=item add_translation

Add localization data

=back

=cut



