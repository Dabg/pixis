use strict;
use utf8;
use Test::More (tests => 4);
use Test::WWW::Mechanize::Catalyst 'Pixis::Web';
BEGIN {
    my $builder = Test::More->builder;
    binmode($builder->output, ':utf8');
    binmode($builder->failure_output, ':utf8');
    binmode($builder->todo_output, ':utf8');
}

my $mech = Test::WWW::Mechanize::Catalyst->new;
$mech->default_headers->push_header('Accept-Language' => 'ja');

$mech->get_ok('/');
$mech->follow_link_ok({text => 'ログイン'});
$mech->submit_form_ok(
    {
        form_number => 1,
        fields => {
            email => 'foo',
            password => 'bar',
        },
        button => 'submit',
    }
);
$mech->content_like(qr/Authentication failed/);
