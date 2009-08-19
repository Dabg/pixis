package Pixis::Catalyst::HandleException;
use Moose::Role;
use Pixis::Web::Exception;
use Storable ();
use namespace::clean -except => qw(meta);

after finalize => sub {
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
        $c->view()->render( $c, 'error.tt', {
            page  => Storable::dclone( $c->controller('Root')->page ),
            error => $error,
        } )
    );

    # processing the error has bombed. just send it back plainly.
    $c->response->body( $error->as_public_html ) if $@;
    return ();
}

1;
