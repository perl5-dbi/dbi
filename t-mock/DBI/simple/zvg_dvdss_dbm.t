#!/usr/bin/perl

BEGIN {
$ENV{DBI_AUTOPROXY} = 'dbi:Gofer:transport=null;policy=pedantic'
}

END {
delete $ENV{DBI_AUTOPROXY};
}

use DBI::Mock;
use DBI::Test::DSN::Provider;

use DBI::Test::Case::DBI::simple::dbm;

my $test_case_conf = DBI::Test::DSN::Provider->get_dsn_creds("DBI::Test::Case::DBI::simple::dbm", ['dbi:DBM:',undef,undef,{dbm_mldbm => 'Storable',dbm_type => 'SDBM_File'}]);
DBI::Test::Case::DBI::simple::dbm->run_test($test_case_conf);

