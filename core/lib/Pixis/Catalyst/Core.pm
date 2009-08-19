package Pixis::Catalyst::Core;
use Moose::Role;
use Template::Provider::Encoding;
use Template::Stash::ForceUTF8;
use namespace::clean -except => qw(meta);

BEGIN {
    my $DEBUG = exists $ENV{PIXIS_DEBUG} ? $ENV{PIXIS_DEBUG} : 0;
    my $config_hack = $ENV{ENABLE_CONFIG_HACK} ? 1 : 0;
    eval <<EOSUB;
sub ENABLE_CONFIG_HACK { $config_hack }
sub debug { return $DEBUG }
EOSUB
}

before setup => sub {
    my ($class, @args) = @_;

    my $config = $class->config;
    $config->{pixis} ||= {};
    $config->{pixis}->{include_path} ||= [
        do {
            my $libpath = Path::Class::File->new( $INC{'Pixis/Web.pm'} );
            $libpath->parent->parent->parent->subdir('root')
        }
    ];
    $class->config( $class->make_config( %{$config} ) );

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
};

sub make_config {
    my ($class, %plugin_config) = @_;

    my @localizers;
    my @modules = ($class, 'Pixis::Web');
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
                    map { $_->subdir('forms')->stringify } @{ $class->config->{pixis}->{include_path} }
                ],
                tt_args => {
                    COMPILE_DIR  => $class->path_to('tt2'),
                    INCLUDE_PATH => [
                        $class->path_to('root', 'forms')->stringify,
                        map { $_->subdir('forms')->stringify } @{ $class->config->{pixis}->{include_path} }
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
                        @{ $class->config->{pixis}->{include_path} }
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

    return $config;
}

1;
