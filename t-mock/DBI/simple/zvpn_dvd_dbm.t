#!/usr/bin/perl

BEGIN {
$ENV{DBI_PUREPERL} = 2;
$ENV{DBI_SQL_NANO} = 1
}

END {
delete $ENV{DBI_PUREPERL};;
delete $ENV{DBI_SQL_NANO};
}

use DBI::Mock;
use DBI::Test::DSN::Provider;

use DBI::Test::Case::DBI::simple::dbm;

my $test_case_conf = DBI::Test::DSN::Provider->get_dsn_creds("DBI::Test::Case::DBI::simple::dbm", ['dbi:DBM:',undef,undef,{}]);
DBI::Test::Case::DBI::simple::dbm->run_test($test_case_conf);

