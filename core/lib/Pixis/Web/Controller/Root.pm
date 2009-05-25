package Pixis::Web::Controller::Root;
use Moose;
use namespace::clean -except => qw(meta);

BEGIN { extends 'Catalyst::Controller' };

__PACKAGE__->config->{namespace} = '';

has site_index => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_site_index',
);

has page => (
    # page variable will contain everything pertinent to the page.
    is => 'ro',
    isa => 'HashRef',
    required => 1,
);

sub BUILDARGS {
    my $class = shift;
    my $args = $class->SUPER::BUILDARGS(@_);

    my $given = $args->{page} || {};
    my $h = Catalyst::Utils::merge_hashes( {
        title => "Pixis - Default Installation",
        base_scripts => [
            '/static/js/jquery-1.3.1.js',
            '/static/js/jquery-ui-1.6rc6.min.js',
            '/static/js/jquery.dump.js',
        ],
        heading => [
            tag => "h1",
            content => "Pixis - Default Installation",
            enabled => 1,
            id => "pagetitle",
        ],
        base_styles => [
            '/static/css/import.css',
            '/static/js/theme/ui.all.css',
        ],
#    scripts:
#        -
#    styles:
#        -
#    metas:
#        -
#    feeds:
#        -
    }, $given);

    $args->{page} = $h;
    return $args;
}

sub begin :Private {
    my ($self, $c) = @_;
    $c->stash->{page} = $self->page;
    return ();
}

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    if ($self->has_site_index) {
        my $index = $self->site_index();
        # user has define some sort of custom index
        $c->res->redirect($c->uri_for($index));
    }

    if ($c->user_exists) {
        $c->res->redirect($c->uri_for('/member/home'));
        $c->finalize();
    }
    return ();
}

sub default :Path {
    Pixis::Web::Exception::FileNotFound->throw();
    return ();
}

sub error :Private {
    my ($self, $c, $comment) = @_;
    Pixis::Web::Exception->new(message => $comment);
    return ();
}

sub end : ActionClass('RenderView') {}

1;
