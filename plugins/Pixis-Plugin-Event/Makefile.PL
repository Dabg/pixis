use strict;
use inc::Module::Install;

name 'Pixis-Plugin-Event';

requires 'DateTime::Format::Duration';
requires 'DateTime::Format::Strptime';
requires 'Encode';
requires 'Moose';
requires 'POSIX';
requires 'namespace::clean';

tests 't/*.t t/*/*.t';

WriteAll;