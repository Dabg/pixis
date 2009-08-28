# IMPORTANT: if you delete this file your app will not work as
# expected.  you have been warned
use inc::Module::Install;

name 'Pixis-Web';
all_from 'lib/Pixis/Web.pm';

requires 'namespace::clean';
requires 'Catalyst::Runtime' => '5.8';
requires 'Catalyst::Controller::HTML::FormFu';
requires 'Catalyst::Authentication::Credential::OAuth';
requires 'Catalyst::Authentication::Credential::Password';
requires 'Catalyst::Authentication::Store::DBIx::Class';
requires 'Catalyst::Model::Data::Localize', '0.00005';
requires 'Catalyst::Model::DBIC::Schema';
requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Plugin::Authorization::Roles';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::I18N';
requires 'Catalyst::Plugin::Session';
requires 'Catalyst::Plugin::Session::State::Cookie';
requires 'Catalyst::Plugin::Session::Store::File';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Plugin::Unicode';
requires 'Catalyst::View::TT';
requires 'Catalyst::View::JSON';
requires 'Catalyst::View::Email';
requires 'Catalyst::View::Download::CSV';
requires 'Catalyst::Action::RenderView';
requires 'parent';
requires 'YAML'; # This should reflect the config file format you've chosen
                 # See Catalyst::Plugin::ConfigLoader for supported formats
requires 'Cache::Memcached';
requires 'Crypt::SSLeay'; # For communication with Paypal
requires 'Data::Localize', '0.00007';
requires 'DateTime';
requires 'DateTime::Format::Duration';
requires 'DateTime::Format::Strptime';
requires 'DBD::mysql';
requires 'DBIx::Class' => '0.08100'; # TxnScopeGuard
requires 'DBIx::Class::VirtualColumns';
requires 'DBIx::Class::TimeStamp';
requires 'Digest::SHA1';
requires 'Exception::Class';
requires 'MooseX::Getopt';
requires 'MooseX::NonMoose';
requires 'MooseX::Types::Path::Class';
requires 'HTML::FormFu';
requires 'HTML::FormFu::Model::DBIC';
requires 'LWP::UserAgent'; 
requires 'Module::Pluggable';
requires 'Moose';
requires 'MooseX::AttributeHelpers';
requires 'MooseX::Types::Path::Class';
requires 'MooseX::Singleton', '0.17';
requires 'MooseX::WithCache';
requires 'SQL::Translator';
requires 'Text::CSV_XS';
requires 'Template::Provider::Encoding';
requires 'Imager';

recommends 'Catalyst::Engine::FastCGI';
recommends 'Catalyst::Log::Log4perl';

test_requires 'Test::More', '0.82';
test_requires 'Test::FITesque';
test_requires 'Test::WWW::Mechanize::Catalyst', '0.51';
test_requires 'Email::Send::Test';
test_requires 'Email::Send::IO';
test_requires 'Email::Send::Test::DataDumper';
test_requires 'File::Find::Rule';
# from github.com/lopnor/Email-Send-Test-DataDumper

catalyst;

tests("t/*.t t/*/*.t");
install_script glob('script/*.pl');

if(! -d "t/logs") {
    mkdir("t/logs");
}

#auto_include;
auto_install;
WriteAll;

print <<EOM;

HOWTO SETUP PIXIS

1. Setup your database

  To setup your database:

    # Just the core
    ./script/pixis_setupdb.pl \
        --dsn="dbi:mysql:dbname=pixis" \
        --user="...." \
        --password="..."

    # to include plugins
    ./script/pixis_cmd.pl ./script/pixis_setupdb.pl \
        --dsn="dbi:mysql:dbname=pixis" \
        --user="...." \
        --password="..."

  Add --drop, if you want to drop the old schema

    ./script/pixis_setupdb.pl ... --drop

2. Start your server

  To start your dev server

    # Just the core
    ./script/pixis_web_server.pl

    # to include plugins
    ./script/pixis_cmd.pl ./script/pixis_web_server.pl

3. To run tests

    # your regular make test:

    make test

EOM
