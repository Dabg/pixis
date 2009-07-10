package Pixis::Web::Controller::Email;
use Moose;
use namespace::clean -except => qw(meta);
use utf8;
use Encode ();

BEGIN { extends 'Pixis::Web::ControllerBase' }

has headers => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1,
);

has mime_encoding_map => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1
);

sub _build_headers {
    return {
        Charset          => 'iso-2022-jp',
        Content_Type     => 'text/plain',
        Content_Encoding => '7bit',
    }
}

sub _build_mime_encoding_map {
    return +{
        'iso-2022-jp' => 'MIME-Header-ISO_2022_JP', 
    }
}

sub send
    :Private
{
    my ($self, $c, $args) = @_;

    my $header = 
        Catalyst::Utils::merge_hashes($self->headers, $args->{header} || {});

    if (! $header->{To} ) {
        Carp::confess("Missing 'To' header");
    }

    if ($header->{Subject}) {
        my $encoding = $self->mime_encoding_map->{ $header->{Charset} };
        $header->{Subject} = Encode::encode($encoding, $header->{Subject});
    }
    my $body = Encode::encode($header->{Charset}, $args->{body});

    if ($header->{Content_Type} !~ /charset=/) {
        $header->{Content_Type} = "$header->{Content_Type}; charset=$header->{Charset}";
    }

    my %args = (
        header       => [%$header],
        content_type => $header->{Content_Type},
        body         => $body,
    );
    local $c->stash->{email} = \%args;

    $c->forward( $c->view('Email') );
    $c->log->info("Sent email to $header->{To} '$header->{Subject}'");

    return ();
}

1;

__END__

=head1 NAME

Pixis::Web::Controller::Email - Send Emails

=head1 SYNOPSIS

    $c->forward('/email/send',
        [ {
            header => {
                To => 'somebody@mydomain',
                Subject => "Hello!",
            },
            body => "Blah Blah Blah"
        } ]
    );

=head1 ATTRIBUTES

=head2 headers

Holds the default set of headers to use. You can always override the headers
by passing them in the argument to send().

=head2 mime_encoding_map

Holds a map from charset to MIME-Heaer-XXXX encoding name.

=cut