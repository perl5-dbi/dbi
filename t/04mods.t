#!perl -w

use strict;
use Test;

BEGIN { plan tests => 3 }

use DBI;

use DBI::Const::GetInfoType qw(%GetInfoType);

use DBI::Const::GetInfoReturn qw(%GetInfoReturnTypes %GetInfoReturnValues);

ok(keys %GetInfoType);

ok(keys %GetInfoReturnTypes);
ok(keys %GetInfoReturnValues);

