#!/usr/bin/perl

BEGIN {
$ENV{DBI_PUREPERL} = 2
}

END {
delete $ENV{DBI_PUREPERL};
}

use DBI::Mock;
use DBI::Test::DSN::Provider;

use DBI::Test::Case::DBI::simple::sql_engine;

my $test_case_conf = DBI::Test::DSN::Provider->get_dsn_creds("DBI::Test::Case::DBI::simple::sql_engine", ['dbi:File:',undef,undef,{}]);
DBI::Test::Case::DBI::simple::sql_engine->run_test($test_case_conf);

