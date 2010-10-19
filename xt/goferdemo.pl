#!perl -w
$|=1;

use strict;
use File::Path;
use File::Spec;
use Cwd;

use DBI;

$ENV{DBI_SQL_NANO}=1;

my $dir = File::Spec->catdir(getcwd(),'test_output');
rmtree $dir;
mkpath $dir;

my $dtype = 'SDBM_File';

my $dbh = DBI->connect( "dbi:DBM:dbm_type=$dtype;lockfile=0" );

for my $sql ( split /\s*;\n/, join '',<DATA> ) {
    $sql =~ s/\S*fruit/${dtype}_fruit/; # include dbm type in table name
    $sql =~ s/;$//;  # in case no final \n on last line of __DATA__
    print " $sql\n";
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute;
    die $sth->errstr if $sth->err and $sql !~ /DROP/;
    next unless $sql =~ /SELECT/;
    while (my ($key, $value) = $sth->fetchrow_array) {
        print "$key: $value\n";
    }
}
$dbh->disconnect;

rmtree $dir;
exit 0;
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
SELECT * FROM fruit;
