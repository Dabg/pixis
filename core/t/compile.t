use strict;
use Test::UseAllModules;

BEGIN {
    all_uses_ok except => qw(
        Pixis::Plagger::.*
    );
}