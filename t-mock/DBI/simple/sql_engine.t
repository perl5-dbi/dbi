#!/usr/bin/perl



use DBI::Mock;
use DBI::Test::DSN::Provider;

use DBI::Test::Case::DBI::simple::sql_engine;

my $test_case_conf = DBI::Test::DSN::Provider->get_dsn_creds("DBI::Test::Case::DBI::simple::sql_engine", ['dbi:File:',undef,undef,{}]);
DBI::Test::Case::DBI::simple::sql_engine->run_test($test_case_conf);

