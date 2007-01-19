#!perl -w                                         # -*- perl -*-
# vim:sw=4:ts=8

use strict;
use warnings;

use Test::More 'no_plan';

use DBI;

use lib "/Users/timbo/dbi/trunk/lib";

my $dsn = "dbi:Forward:transport=null;dsn=dbi:DBM:dbm_type=SDBM_File;lockfile=0";
my $dbh = DBI->connect($dsn);
ok $dbh, 'should connect';


    # 0=SQL::Statement if avail, 1=DBI::SQL::Nano
    # next line forces use of Nano rather than default behaviour
    $ENV{DBI_SQL_NANO}=1;

#my $dir = './test_output';
#rmtree $dir;
#mkpath $dir;

my @sql = split /\s*;\n/, join '',<DATA>;

for my $sql ( @sql ) {
    $sql =~ s/;$//;  # in case no final \n on last line of __DATA__
    my $null = '';
    my $expected_results = {
        1 => 'oranges',
        2 => 'apples',
        3 => $null,
    };
    if ($sql !~ /SELECT/) {
        print " do $sql\n";
        $dbh->do($sql) or die $dbh->errstr;
        next;
    }
    print " run $sql\n";
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute;
    die $sth->errstr if $sth->err and $sql !~ /DROP/;
    # Note that we can't rely on the order here, it's not portable,
    # different DBMs (or versions) will return different orders.
    while (my ($key, $value) = $sth->fetchrow_array) {
        ok exists $expected_results->{$key};
        is $value, $expected_results->{$key};
    }
    is $DBI::rows, keys %$expected_results;
}
$dbh->disconnect;

1;
__DATA__
DROP TABLE IF EXISTS fruit;
CREATE TABLE fruit (dKey INT, dVal VARCHAR(10));
INSERT INTO  fruit VALUES (1,'oranges'   );
INSERT INTO  fruit VALUES (2,'to_change' );
INSERT INTO  fruit VALUES (3, NULL       );
INSERT INTO  fruit VALUES (4,'to delete' );
UPDATE fruit SET dVal='apples' WHERE dKey=2;
DELETE FROM  fruit WHERE dVal='to delete';
SELECT * FROM fruit;
DROP TABLE fruit;
