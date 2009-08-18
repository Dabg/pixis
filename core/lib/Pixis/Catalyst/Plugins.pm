package Pixis::Catalyst::Plugins;
use Moose::Role;
use namespace::clean -except => qw(meta);

my %TT_ARGS            = ();
my @PLUGINS            = ();
my %REGISTERED_PLUGINS = ();

after setup_finalize => sub {
    my $self = shift;
    $self->setup_pixis_plugins();
};

sub setup_pixis_plugins {
    my $self = shift;

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

    my $view = $self->view();
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

1;
