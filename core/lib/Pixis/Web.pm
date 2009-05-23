package Pixis::Web;
use Moose;
use namespace::clean -except => qw(meta);

# XXX Note to self: You /HAVE/ to say use Catalyst before doing anything
# that depends on $c->config->{home} (such as ->path_to()), as import()
# is where the initialization gets triggered
use Catalyst;

use Module::Pluggable::Object;

our $VERSION = '0.01';


# if you have Log4perl installed, you get colored messages. Yey!
use constant HAVE_LOG4PERL => eval {
    require Catalyst::Log::Log4perl;
    1;
};

use Template::Provider::Encoding;
use Template::Stash::ForceUTF8;

use Pixis::Hacks;
use Pixis::Registry;
use Pixis::Web::Exception;
use Catalyst::Runtime '5.80';
our $REGISTRY;

BEGIN {
    $REGISTRY = Pixis::Registry->instance;
    extends 'Catalyst';
}

sub setup {
    my $class = shift;
    $class->SUPER::setup(qw/
        Unicode
        Authentication
        Authorization::Roles
        ConfigLoader
        Data::Localize
        Session
        Session::Store::File
        Session::State::Cookie
        Static::Simple
    /);
}


sub setup_components {
    my $class = shift;
    if ($class eq 'Pixis::Web') {
        return $class->SUPER::setup_components(@_);
    }

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
        $comp =~ s/^Pixis::Web/$class/;
print "Declaring $comp as a subclass of $base\n";
        my $meta =
            Moose::Meta::Class->create($comp, superclasses => [ $base ]);
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

sub setup_config {
    my $class = shift;
    $class->SUPER::config(
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
                tt_args => {
                    COMPILE_DIR  => $class->path_to('tt2'),
                    INCLUDE_PATH => $class->path_to('root', 'forms')->stringify,
                }
            }
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
                    INCLUDE_PATH => [ $class->path_to('root') ],
                    COMPILE_DIR  => $class->path_to('tt2'),
                  }
                }
            ],
            STASH   => Template::Stash::ForceUTF8->new,
        }
    );
}

if (caller() eq 'main') {
    __PACKAGE__->setup_config();
    __PACKAGE__->setup() ;
}
    
# mk_classdata is overkill for these.
my %REGISTERED_PLUGINS = ();
my %TT_ARGS            = ();
my @PLUGINS            = ();

sub registry { ## no critic
    shift;
    # XXX the initialization code is currently at Model::API. Should this
    # be changed?
    return $REGISTRY->get(@_);
}

sub setup_log {
    my $self = shift;
    if (! HAVE_LOG4PERL) {
        $self->SUPER::setup_log(@_);
    }
    $self->log(
        Catalyst::Log::Log4perl->new(
            $self->path_to('Log4perl.conf')->stringify,
            (autoflush => 1, watch_delay => 5, override_cspecs => 1)
        )
    );
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
            'Pixis::Web::Plugin'
        ],
        %$config,
    );

    my @plugins = $mpo->plugins;

    foreach my $plugin (@plugins) {
        my $pkg = $plugin;
        my $args = $self->config->{plugins}->{config}->{$plugin} || {} ;
        $self->log->debug("[Pixis Plugin]: Loading plugin $pkg")
            if $self->log->is_debug;
        eval {
            Class::MOP::load_class($pkg);
        };
        if ($@) {
            $self->log->error("[Pixis Plugin]: Failed to load $plugin: $@");
            confess("Initialization failed during plugin load for $plugin: $@");
        }
        $plugin = $pkg->new(%$args);
        if (! $plugin->registered && !($REGISTERED_PLUGINS{ $pkg }++) ){
            $self->log->debug("[Pixis Plugin]: Registering $pkg")
                if $self->log->is_debug;
            eval {
                $plugin->register($self);
            };
            if ($@) {
                $self->log->error("[Pixis Plugin]: Failed to register $plugin: $@");
                confess("Initialization failed during plugin registration for $plugin: $@");
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
warn "adding @paths";
    $view->include_path(
        @paths,
        @{ $view->include_path }
    );
warn "    -> " . join(", ", @{$view->include_path});
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

sub add_formfu_path {
    my ($self, @paths) = @_;

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

before finalize => sub {
    my $c = shift;
    $c->handle_exception if @{ $c->error };
};

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

=head1 WRITING PLUGINS

To write a plugin, create an object that implements 'register'. Use the following methods to add the appropriate 'stuff' for your plugin:

=over 4

=item add_tt_include_path

Adds include paths for your templates

=item add_navigation

Add a hash that gets translated into the (global) navigation bar

=item add_translation

Add localization data

=back

=head1 TODO

how to hijack the application?

    package MyApp 
    use Moose
    extends Pixis::Web ?

You can't generate controllers in memory?

=cut



