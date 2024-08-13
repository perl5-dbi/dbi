#!/usr/bin/perl

BEGIN {
$ENV{DBI_MOCK} = 1;
}


use DBI::Mock;
use DBI::Test::DSN::Provider;

use DBI::Test::Case::SQL::Statement::error;

my $test_case_conf = DBI::Test::DSN::Provider->get_dsn_creds("DBI::Test::Case::SQL::Statement::error", ['dbi:NullP:',undef,undef,{}]);
DBI::Test::Case::SQL::Statement::error->run_test($test_case_conf);

