package Pixis::Web;
use Moose;
use namespace::clean -except => qw(meta);

# XXX Note to self: You /HAVE/ to say use Catalyst before doing anything
# that depends on $c->config->{home} (such as ->path_to()), as import()
# is where the initialization gets triggered
use Catalyst;
use Catalyst::Runtime '5.80';

with 'Pixis::Hub';

our $VERSION = '0.01';
my $DEBUG = exists $ENV{PIXIS_DEBUG} ? $ENV{PIXIS_DEBUG} : 0;

use Template::Provider::Encoding;
use Template::Stash::ForceUTF8;
use Pixis;
use Pixis::Hacks;

BEGIN {
    extends 'Catalyst';

    my $config_hack = $ENV{ENABLE_CONFIG_HACK} ? 1 : 0;
    eval <<EOSUB;
sub ENABLE_CONFIG_HACK { $config_hack }
EOSUB
}

sub debug { return $DEBUG }
sub setup {
    my ($class, %plugin_config) = @_;

    my @plugins = qw/
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
    /;

    if (my $plugins = $plugin_config{plugins}) {
        foreach my $plugin (@$plugins) {
            push @plugins, $plugin;
        }
    }

    if (my $plugins = $plugin_config{disable}) {
        my %disabled = map { ($_ => 1) } @$plugins;
        @plugins = grep { ! $disabled{ $_ } } @plugins;
    }

    # XXX FIXME FIXME FIXME XXX
    # This is an ungly hack that prevents Catalyst from garbling our output.
    # This only happens when you have configuration values that are put
    # directly to the output stream -- like, contents of the header section
    # together with our utf-8 body. I'm thinking this has something to do
    # with how YAML::Syck loads unicode + C::P::Unicode's way of handling
    # output data, but not sure at this point.
    #
    # set Pixis::Web::ENABLE_CONFIG_HACK to a false value if you want to
    # disable this ugliness.
    if (ENABLE_CONFIG_HACK) {
        Encode::from_to($class->config->{session}->{cookie_domain}, "iso-8859-1", "utf-8");
    }

    $class->SUPER::setup(@plugins);

    $plugin_config{ roles } = [ qw(
        Pixis::Catalyst::HandleException
        Pixis::Catalyst::Plugins
        Pixis::Catalyst::VirtualComponents
    ) ];
        
    Moose::Util::apply_all_roles( $class->meta, @{ $plugin_config{roles} } );

    return ();
}

sub setup_config {
    my ($class, %plugin_config) = @_;

    my @localizers;
    my @modules = ($class, 'Pixis');
    foreach my $module (@modules) {
        my $modpath = $module;
        $modpath =~ s/::/\//g;
        $modpath .= '.pm';
        my $path = $INC{ $modpath };
        next unless $path;

        $path =~ s/\.pm$//;

        # find in MyApp::I18N, and possibly (for those of us using a setup
        # like MyApp::Catalyst or MyApp::Web), one level above
        my @paths = # map { File::Spec->canonpath($_) } (
(
            File::Spec->catdir($path, 'I18N'),
            File::Spec->catdir($path, File::Spec->updir(), 'I18N'),
        );
        foreach my $curpath (@paths) {
            next unless -d $curpath;
            my $gettext = File::Spec->catfile($curpath, '*.po');
            # Huh, why isn't this working?
#            if (defined glob($gettext)) {
                push @localizers, {
                    class => 'Gettext',
                    paths => [ $gettext ]
                };
#            }

            my $namespace = File::Spec->catfile($path, '*.pm');
            if (defined glob($namespace)) {
                push @localizers, {
                    class => 'Namespace',
                    namespaces => [ join('::', $module, 'I18N' ) ]
                }
            }
        }
    }

    my $config = {
        name => $class,
        default_view => 'TT',
        static => {
            dirs => [ 'static' ]
        },
        'Model::FormFu' => {
            formfu_config => {
                render_method => 'tt',
                config_file_path => [
                    $class->path_to('root', 'forms')->stringify,
                    __PACKAGE__->path_to('root', 'forms')->stringify,
                ],
                tt_args => {
                    COMPILE_DIR  => $class->path_to('tt2'),
                    INCLUDE_PATH => [
                        $class->path_to('root', 'forms')->stringify,
                        __PACKAGE__->path_to('root', 'forms')->stringify,
                    ]
                }
            }
        },
        'Model::Data::Localize' => {
            localizers => \@localizers
        },
        'Plugin::Authentication' => {
            use_session => 1,
            default_realm => 'members',
            realms => {
                members => {
                    credential => {
                        class => 'Password',
                        password_field => 'password',
                        password_type  => 'hashed',
                        password_hash_type => 'SHA-1',
                    },
                    store => {
                        class => 'DBIx::Class',
                        id_field => 'email',
                        role_column => 'roles',
                        user_class => 'DBIC::Member',
                    }
                },
                members_internal => {
                    credential => {
                        class => 'Password',
                        password_field => 'password',
                        password_type  => 'clear',
                    },
                    store => {
                        class => 'DBIx::Class',
                        id_field => 'email',
                        role_column => 'roles',
                        user_class => 'DBIC::Member',
                    }
                }
            }
        },
        'View::JSON' => {
            expose_stash => 'json'
        },
        'View::TT' => {
            PRE_PROCESS => 'preprocess.tt',
            PROVIDERS => [
                { name => 'Encoding',
                  args => {
                    INCLUDE_PATH => [
                        $class->path_to('root'),
                        __PACKAGE__->path_to('root'),
                    ],
                    COMPILE_DIR  => $class->path_to('tt2'),
                  }
                }
            ],
            STASH   => Template::Stash::ForceUTF8->new,
        }
    };

    %plugin_config and
        $config = Catalyst::Utils::merge_hashes($config, \%plugin_config);

    return $class->config($config);
}

my $caller = caller();
if ($caller eq 'main' || $ENV{HARNESS_ACTIVE}) {
    __PACKAGE__->setup_config();
    __PACKAGE__->setup() ;
}
    
1;

__END__

=head1 NAME

Pixis::Web - Extensible Catalyst Application Framework

=head1 SYNOPSIS

    package MyApp;
    use Moose;
    use Catalyst;
    use namespace::clean -except => qw(meta);

    BEGIN { extends 'Pixis::Web' }

    __PACKAGE__->setup_config(
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



