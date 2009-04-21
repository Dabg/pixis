use strict;
use utf8;
use Test::More (tests => 1);
use Apache::Test qw(:withtestmore);
use Apache::TestRequest qw(GET_BODY);
use Encode;
use URI;
# use Test::WWW::Mechanize;

{
    my $content = decode_utf8(GET_BODY '/', 'Accept-Language' => 'ja');
    like($content, qr/Perlで書かれたSNSプラットフォーム/, encode_utf8("'Perlで書かれたSNSプラットフォーム' found"));
}
