package Pixis::Catalyst::VirtualComponents;
use Moose::Role;
use Module::Pluggable::Object;
use namespace::clean -except => qw(meta);

my %VIRTUAL_COMPONENTS;

sub has_virtual_component {
    my ($self, $comp) = @_;
    return exists $VIRTUAL_COMPONENTS{ $comp };
}

sub register_virtual_component {
    my ($self, $comp) = @_;
    $VIRTUAL_COMPONENTS{ $comp }++;
}

override setup_components => sub {
    my $class = shift;

    # add these directories to include path
    my $dirs = $class->config->{ setup_components }->{ include } || [];
    if ( ref $dirs ne 'ARRAY' ) {
        $dirs = [ $dirs ];
    }
    unshift @INC, @$dirs;

    if ($class eq 'Pixis::Web') {
        return $class->SUPER::setup_components(@_);
    }

    $class->_setup_virtual_components();
    $class->_setup_concrete_components();

    return ();
};

sub _setup_virtual_components {
    my $class   = shift;

    # First, search for pixis components so we can try to generate
    # virtual classes
    my @comps = $class->_search_components( 'Pixis::Web' );
    my %comps = map { $_ => 1 } @comps;

    my $t;
    if ($class->debug) {
        my $column_width = Catalyst::Utils::term_width() - 6 - 11;
        $t = Text::SimpleTable->new([ $column_width, 'Component' ], [ 8, 'Type' ]);
    }

    foreach my $comp (@comps) {
        # XXX perl 5.10 seems to pick this up
        next if $comp =~ /::SUPER$/;
        # uh-uh, no no, no controller base
        next if $comp =~ /^Pixis::Web::ControllerBase/;

        # save this component name so we can use this as the base class
        my $base = $comp;

        # now try to create a new class name
        $comp =~ s/^Pixis::Web/$class/;

        # try to load this new class. If it exists, then we don't have to
        # create a new virtual class
        eval { Class::MOP::load_class($comp) };
        if (! $@) {
            $t->row( $comp, 'concrete' );
            next;
        } else {
            $t->row( $comp, 'virtual' );
        }

        # if we got here, then there's no class named $comp.
        # Create it!
        my $meta =
            Moose::Meta::Class->create($comp, superclasses => [ $base ]);
        $class->register_virtual_component( $comp );
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

    if ($class->debug) {
        $class->log->debug( "Virtual Components:\n" . $t->draw );
    }

    return ();
}

sub _setup_concrete_components {
    my $class = shift;

    my @comps = grep { ! $class->has_virtual_component($_) }
        $class->_search_components( $class );
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

sub _search_components {
    my ($class, $namespace) = @_;

    my @paths   = qw( ::Controller ::C ::Model ::M ::View ::V );
    my $config  = $class->config->{ setup_components };
    my $extra   = delete $config->{ search_extra } || [];

    my @search_path = map {
        s/^(?=::)/$namespace/;
        $_;
    } @paths;
    push @search_path, @$extra;

    my $locator = Module::Pluggable::Object->new(
        search_path => [ @search_path ],
        %$config
    );

    my @comps = sort { length $a <=> length $b } $locator->plugins;
    return @comps;
}

1;