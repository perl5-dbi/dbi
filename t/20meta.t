#!../perl -w

use Test;

BEGIN { plan tests => 6 }

$|=1;
$^W=1;

use DBI qw(:sql_types);

use DBI::DBD::Metadata; # just to check for syntax errors etc

$dbh = DBI->connect("dbi:ExampleP:.","","", { FetchHashKeyName => 'NAME_lc' })
	or die "Unable to connect to ExampleP driver: $DBI::errstr";

ok($dbh);
#$dbh->trace(3);

#use Data::Dumper;
#print Dumper($dbh->type_info_all);
#print Dumper($dbh->type_info);
#print Dumper($dbh->type_info(DBI::SQL_INTEGER));

my @ti = $dbh->type_info;
ok(@ti>0);

ok($dbh->type_info(SQL_INTEGER)->{DATA_TYPE}, SQL_INTEGER);
ok($dbh->type_info(SQL_INTEGER)->{TYPE_NAME}, 'INTEGER');

ok($dbh->type_info(SQL_VARCHAR)->{DATA_TYPE}, SQL_VARCHAR);
ok($dbh->type_info(SQL_VARCHAR)->{TYPE_NAME}, 'VARCHAR');

