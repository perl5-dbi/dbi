#!perl -w

use strict;
use Test::More;

BEGIN {
    $ENV{DBI_SQL_NANO}=1;    # 0=SQL::Statement 1=DBI::SQL::Nano
    use lib './'             # to find the new DBD::File
}
use DBI;

BEGIN { plan tests => 8 }

$|=1;
my $dbh = DBI->connect('dbi:DBM(RaiseError=0,PrintError=0):f_foo=bar');
ok($dbh);

#
# dbm_type defaults to AnyDBM_File which uses the @INC to find
# the DBM type. See AnyDBM_File docs for default order.
#
# the user may also specify a dbm_type in the connect() or afterwards
# for example:
#	$dbh->{dbm_type}='MLDBM';
#	$dbh->{dbm_type}='SDBM_File';
#
# It should be possible to have multiple tables, each using different
# DBMs in the same database handle.
#

printf "\n%s %s\n%s %s\n%s %s\n%s %s\n",
         'DBD::DBM'       , $dbh->{Driver}->{Version} || 'undef'
       , 'DBD::File'      , $dbh->{Driver}->{file_version} || 'undef'
       , 'DBI::SQL::Nano' , $dbh->{Driver}->{nano_version} || 'undef'
       , 'SQL::Statement' , $dbh->{Driver}->{statement_version} || 'undef'
       ;

for my $sql (split /;\s*\n+/,join '',<DATA>) {

    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute;
    die $sth->errstr if $sth->errstr and $sql !~ /DROP/;
    next unless $sql =~ /SELECT/;

    my $results='';
    my $expected_results = {
	1 => 'oranges',
	2 => 'apples',
	3 => '',	# NULL returned as undef, currently
    };
    # Note that we can't rely on the order here, it's not portable,
    # different DBMs (or versions) will return different orders.
    while (my ($key, $value) = $sth->fetchrow_array) {
        ok exists $expected_results->{$key};
	is $value, $expected_results->{$key};
    }
    is $DBI::rows, keys %$expected_results;
}

1;
__DATA__
DROP TABLE fruit;
CREATE TABLE fruit (dKey INT, dVal VARCHAR(10));
INSERT INTO  fruit VALUES (1,'oranges'   );
INSERT INTO  fruit VALUES (2,'to_change' );
INSERT INTO  fruit VALUES (3, NULL       );
INSERT INTO  fruit VALUES (4,'to_delete' );
DELETE FROM  fruit WHERE dKey=4;
UPDATE fruit SET dVal='apples' WHERE dKey=2;
SELECT * FROM fruit;
DROP TABLE fruit;
