package Pixis::Web::Controller::Email;
use Moose;
use namespace::clean -except => qw(meta);

BEGIN { extends 'Catalyst::Controller' }

use utf8;
use Encode ();

sub send :Private {
    my ($self, $c, $args) = @_;

    my $config = $self->config;
    my $header = $args->{header} || {};
    if (! $header->{To} ) {
        Carp::confess("Missing 'To' header");
    }

    # XXX Some header are Japanese specific... do we generalize it?
    $header->{From}             ||= $config->{From};
    $header->{Subject}          ||= $config->{Subject};
    $header->{Content_Encoding} ||= '7bit';

    $header->{Cc}  ||= $config->{Cc} if $config->{Cc};
    $header->{Bcc} ||= $config->{Bcc} if $config->{Bcc};

    if ($header->{Subject}) {
        $header->{Subject} = Encode::encode('MIME-Header-ISO_2022_JP', $header->{Subject});
    }
    my $body = Encode::encode('iso-2022-jp', $args->{body});

    my %args = (
        header       => [%$header],
        content_type => 'text/plain; charset=iso-2022-jp',
        body         => $body,
    );
    local $c->stash->{email} = \%args;

    $c->forward( $c->view('Email') );
    return ();
}

1;