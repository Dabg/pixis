package Pixis::Web;
use Moose;
use namespace::clean -except => qw(meta);

# XXX Note to self: You /HAVE/ to say use Catalyst before doing anything
# that depends on $c->config->{home} (such as ->path_to()), as import()
# is where the initialization gets triggered
use Catalyst;

our $VERSION = '0.01';
# mk_classdata is overkill for these.
my %REGISTERED_PLUGINS = ();
my %TT_ARGS            = ();
my @PLUGINS            = ();
my %VIRTUAL_COMPONENTS = ();
my $DEBUG              = exists $ENV{PIXIS_DEBUG} ? $ENV{PIXIS_DEBUG} : 0;

use Template::Provider::Encoding;
use Template::Stash::ForceUTF8;
use Module::Pluggable::Object;
use Pixis;
use Pixis::Hacks;
use Pixis::Registry;
use Pixis::Web::Exception;
use Catalyst::Runtime '5.80';
our $REGISTRY;

BEGIN {
    $REGISTRY = Pixis::Registry->instance;
    extends 'Catalyst';
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
        Static::Simple
        /;

    $plugin_config{plugins} and
        push @plugins, $_ foreach @{$plugin_config{plugins}};

    $class->SUPER::setup(@plugins);

    # Apply hooks AFTER!
    $class->meta->add_before_method_modifier(finalize => sub {
        my $c = shift;
        $c->handle_exception if @{ $c->error };
    });

    return ();
}


sub setup_components {
    my $class = shift;
    if ($class eq 'Pixis::Web') {
        return $class->SUPER::setup_components(@_);
    }

    $class->setup_virtual_components();
    $class->setup_concrete_components();

    return ();
}

sub setup_virtual_components {
    my $class   = shift;

    %VIRTUAL_COMPONENTS = ();
    my @paths   = qw( ::Controller ::C ::Model ::M ::View ::V );
    my $config  = $class->config->{ setup_components };
    my $extra   = delete $config->{ search_extra } || [];

    push @paths, @$extra;

    my $locator = Module::Pluggable::Object->new(
        search_path => [ 'Pixis::Web' ],
        %$config
    );

    my @comps = sort { length $a <=> length $b } $locator->plugins;
    my %comps = map { $_ => 1 } @comps;

    foreach my $comp (@comps) {
        my $base = $comp;
        # uh-uh, no no, no controller base
        next if $comp =~ /^Pixis::Web::ControllerBase/;

        $comp =~ s/^Pixis::Web/$class/;

        eval { Class::MOP::load_class($comp) };
        if (! $@) {
            next;
        }
        $class->log->debug( "Setting up virtual class $comp" )
            if $class->debug;
        my $meta =
            Moose::Meta::Class->create($comp, superclasses => [ $base ]);
        $VIRTUAL_COMPONENTS{$comp}++;
        my $module = $class->setup_component($comp);
        my %modules = (
            $comp => $module,
            map {
                $_ => $class->setup_component($_)
            } grep {
                not exists $comps{$_}
            } Devel::InnerPackage::list_packages( $comp )
        );

        for my $key ( keys %modules ) {
            $class->components->{ $key } = $modules{ $key };
        }
    }
    return ();
}

sub setup_concrete_components {
    my $class = shift;

    my @paths   = qw( ::Controller ::C ::Model ::M ::View ::V );
    my $config  = $class->config->{ setup_components };
    my $extra   = delete $config->{ search_extra } || [];

    push @paths, @$extra;

    my $locator = Module::Pluggable::Object->new(
        search_path => [ map { 
            my $x = $_;
            $x =~ s/^(?=::)/$class/;
            $x;
        } @paths ],
        %$config
    );

    my @comps =
        sort { length $a <=> length $b } 
        grep { ! $VIRTUAL_COMPONENTS{$_} }
        $locator->plugins;
    my %comps = map { $_ => 1 } @comps;

    my $deprecated_component_names = grep { /::[CMV]::/ } @comps;
    $class->log->warn(qq{Your application is using the deprecated ::[MVC]:: type naming scheme.\n}.
        qq{Please switch your class names to ::Model::, ::View:: and ::Controller: as appropriate.\n}
    ) if $deprecated_component_names;

    for my $component ( @comps ) {

        # We pass ignore_loaded here so that overlay files for (e.g.)
        # Model::DBI::Schema sub-classes are loaded - if it's in @comps
        # we know M::P::O found a file on disk so this is safe

        Catalyst::Utils::ensure_class_loaded( $component, { ignore_loaded => 1 } );
        #Class::MOP::load_class($component);

        my $module  = $class->setup_component( $component );
        my %modules = (
            $component => $module,
            map {
                $_ => $class->setup_component( $_ )
            } grep {
              not exists $comps{$_}
            } Devel::InnerPackage::list_packages( $component )
        );

        for my $key ( keys %modules ) {
            $class->components->{ $key } = $modules{ $key };
        }
    }

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
        'Controller::HTML::FormFu' => {
            languages_from_context  => 1,
            localize_from_context  => 1,
            constructor => {
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

    return $class->SUPER::config($config);
}

my $caller = caller();
if ($caller eq 'main' || $ENV{HARNESS_ACTIVE}) {
    __PACKAGE__->setup_config();
    __PACKAGE__->setup() ;
}
    
sub registry { ## no critic
    shift;
    # XXX the initialization code is currently at Model::API. Should this
    # be changed?
    return $REGISTRY->get(@_);
}

sub setup_finalize {
    my ($self, @args) = @_;

    $self->next::method(@args);

    $self->setup_pixis_plugins();
    return;
};

sub setup_pixis_plugins {
    my $self = shift;

    $REGISTRY->set(pixis => web => $self);

    # set the search path so we can look for plugins
    my $search_path = $self->config->{plugins}->{search_path} || [];
    # make sure the paths contain valid-ish (defined) items
    $search_path = [ grep { defined $_ && length $_ > 0 } @$search_path ];
    unshift @INC, @$search_path if scalar @$search_path;

    # Core must be read-in before everything else
    # (it will be discovered by Module::Pluggable, and we wouldn't
    # load it twice anyway, so we're safe to just stick it in the front)

    my $config = $self->config->{plugin_loader} || {};

    my $mpo = Module::Pluggable::Object->new(
        require => 0,
        search_path => [
            'Pixis::Plugin',
            'Pixis::Web::Plugin',
        ],
        %$config,
    );

    my @plugins = grep { $_ ne 'Pixis::Plugin::Core' } $mpo->plugins;
    unshift @plugins, 'Pixis::Plugin::Core';

    foreach my $plugin (@plugins) {
        my $pkg = $plugin;
        my $args = $self->config->{$plugin} || {} ;
        $self->log->debug("[Pixis Plugin]: Loading plugin $pkg")
            if $self->debug;
        eval {
            Class::MOP::load_class($pkg);
        };
        if ($@) {
            my $err = $@;
            $self->log->error("[Pixis Plugin]: Failed to load $plugin: '$err'");
            confess("Initialization failed during plugin load for $plugin: '$err'");
        }
        $plugin = $pkg->new(%$args);
        if (! $plugin->registered && !($REGISTERED_PLUGINS{ $pkg }++) ){
            $self->log->debug("[Pixis Plugin]: Registering $pkg")
                if $self->debug;
            eval {
                $plugin->register($self);
            };
            if ($@) {
                my $err = $@;
                $self->log->error("[Pixis Plugin]: Failed to register $plugin: '$err'");
                confess("Initialization failed during plugin registration for $plugin: '$err'");
            }
            $plugin->registered(1);
            push @PLUGINS, $plugin;
        }
    }
    return ();
}

sub plugins { return \@PLUGINS }

# Note: This exists *solely* for the benefit of pixis_web_server.pl
# In your real app (fastcgi deployment suggested), you need to do something
# like:
#   Alias /static/<plugin>  /path/to/plugin/root/static/<plugin>
sub add_static_include_path {
    my ($self, @paths) = @_;

    my $config = $self->config->{static};
    $config->{include_path} ||= [];
    push @{$config->{include_path}}, @paths;
    return ();
}

sub add_tt_include_path {
    my ($self, @paths) = @_;

    @paths = grep { defined && length } @paths;
    return unless @paths;

    my $view = $self->view('TT');
    my $providers = $view->template->{SERVICE}->{CONTEXT}->{CONFIG}->{LOAD_TEMPLATES};
    if ($providers) {
        foreach my $provider (@$providers) {
            $provider->include_path([
                @paths,
                @{ $provider->include_path || [] }
            ]);
        }
    }
    $view->include_path(
        @paths,
        @{ $view->include_path }
    );
    return ();
}

sub add_translation_path {
    my ($self, @paths) = @_;

    # we're using gettext by default, just look for a localize by that
    # type in the localizer
    my $localize = $self->model('Data::Localize');
    my ($localizer) = $localize->find_localizers(isa => 'Data::Localize::Gettext');
    if (! $localizer) {
        $self->log->warn("No localizer available?!");
    } else {
        $localizer->path_add( $_ ) for @paths;
    }

    return ();
}

# XXX FIXME - plugins should probably access the model directly
sub add_formfu_path {
    my ($self, @paths) = @_;
    return $self->model('FormFu')->add_config_file_path(@paths);
}

=head1
sub add_formfu_path {
    my ($self, @paths) = @_;

    @paths = map { File::Spec->canonpath($_) } @paths;
    foreach my $controller (map { $self->controller($_) } $self->controllers) {
        my $code = $controller->can('_html_formfu_config');
        next unless $code;

        my $orig   = $code->($controller)->{constructor}{config_file_path};
        if (defined $orig && ref($orig) ne 'ARRAY') {
            $orig = [$orig];
            $code->($controller)->{constructor}{config_file_path} = $orig;
        }
        my %seen = map { ($_ => 1) } @$orig;
        foreach my $path (@paths) {
            next if $seen{$path};
            push @$orig, $path;
        }
    }

    return ();
}
=cut


sub handle_exception {
    my( $c )  = @_;
    my $error = $c->error->[ 0 ];

    if( !Scalar::Util::blessed( $error ) || !$error->isa( 'Pixis::Web::Exception' ) ) {
        $error = Pixis::Web::Exception->new( message => "$error" );
    }

    # handle debug-mode forced-debug from RenderView
    if( $c->debug && $error->message =~ m{Forced debug}i ) {
        return;
    }

    # handle debug-mode forced-debug from RenderView
    $c->clear_errors;

    if ( $error->is_error ) {
        $c->response->headers->remove_content_headers;
    }

    if ( $error->has_headers ) {
        $c->response->headers->merge( $error->headers );
    }

    # log the error
    if ( $error->is_server_error ) {
        $c->log->error( $error->as_string );
    }
    elsif ( $error->is_client_error ) {
        $c->log->warn( join(' ', $c->request->uri, $error->status, $error->as_string ) ) if $error->status =~ /^40[034]$/;
    }

    if( $error->is_redirect ) {
        # recent Catalyst will give us a default body for redirects

        if( $error->can( 'uri' ) ) {
            $c->response->redirect( $error->uri( $c ) );
        }

        return;
    }

    $c->response->status( $error->status );
    $c->response->content_type( 'text/html; charset=utf-8' );
    $c->response->body(
        $c->view( 'TT' )->render( $c, 'error.tt', { error => $error } )
    );

    # processing the error has bombed. just send it back plainly.
    $c->response->body( $error->as_public_html ) if $@;
    return ();
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



