#!/usr/bin/perl

BEGIN {
$ENV{DBI_PUREPERL} = 2;
$ENV{DBI_AUTOPROXY} = 'dbi:Gofer:transport=null;policy=pedantic'
}

END {
delete $ENV{DBI_PUREPERL};;
delete $ENV{DBI_AUTOPROXY};
}

use DBI::Mock;
use DBI::Test::DSN::Provider;

use DBI::Test::Case::DBI::simple::file;

my $test_case_conf = DBI::Test::DSN::Provider->get_dsn_creds("DBI::Test::Case::DBI::simple::file", ['dbi:File:',undef,undef,{}]);
DBI::Test::Case::DBI::simple::file->run_test($test_case_conf);

