# This script checks with style of WHERE clause(s) will support both
# null and non-null values.  Refer to the NULL Values sub-section
# of the "Placeholders and Bind Values" section in the DBI
# documention for more information on this issue.  The clause styles
# and their numbering (0-6) map directly to the examples in the
# documentation.
#
# To use this script, update the connect method arguments to support
# your database engine and database.  Set PrintError to 1 if you want
# see the reason WHY your engine won't support a particular style.
#
# Warning: This script will attempt to create a table named by the
# $tablename variable (default dbi__null_test_tmp) and WILL DESTROY
# any pre-existing table so named.

use strict;
use DBI;

my $tablename = "dbi__null_test_tmp"; # DESTROYs this table. Must be obscure

die "DBI_DSN environment variable not defined"
	unless $ENV{DBI_DSN};

my $dbh = DBI->connect(undef, undef, undef, {
	RaiseError => 0,
	PrintError => 1
    }
);

my $sth;
my @ok;

print "=> Drop table '$tablename', if it already exists...\n";
$sth = $dbh->do("DROP TABLE $tablename");

print "=> Create table '$tablename'...\n";
$sth = $dbh->prepare("CREATE TABLE $tablename (key int, mycol char(8))");
$sth->execute();

print "=> Insert 4 rows into the table...\n";
my @stv = ('slow', undef, 'quick', undef);
$sth = $dbh->prepare("INSERT INTO $tablename (key, mycol) VALUES (?,?)");
for my $i (0..3)
{
    $sth->execute($i+1, $stv[$i]); 
}

# Define the SQL statements with the various WHERE clause styles we want to test.

my @sel = (
  qq{WHERE mycol = ?},
  qq{WHERE NVL(mycol, '-') = NVL(?, '-')},
  qq{WHERE ISNULL(mycol, '-') = ISNULL(?, '-')},
  qq{WHERE DECODE(mycol, ?, 1, 0) = 1},
  qq{WHERE mycol = ? OR (mycol IS NULL AND ? IS NULL)},
  qq{WHERE mycol = ? OR (mycol IS NULL AND SP_ISNULL(?) = 1)},
  qq{WHERE mycol = ? OR (mycol IS NULL AND ? = 1)},
);

# Define the execute method argument lists for non-null values.
# The order must map one to one with the above SQL statements.

my @nonnull_args = (
  ['quick'],
  ['quick'],
  ['quick'],
  ['quick'],
  ['quick','quick'],
  ['quick','quick'],
  ['quick', 0],
);

# Define the execute method argument lists for null values.
# The order must map one to one with the above SQL statements.

my @null_args = (
  [undef],
  [undef],
  [undef],
  [undef],
  [undef, undef],
  [undef, undef],
  [undef, 1],
);

# Run the tests...

for my $i (0..@sel-1)
{
    print "\n=> Testing clause style $i: $sel[$i]\n";
    $sth = $dbh->prepare("SELECT key,mycol FROM $tablename $sel[$i]")
	or next;

    $sth->execute(@{$nonnull_args[$i]})
	or next;
    my $r1 = $sth->fetchall_arrayref();
    my $n1 = $sth->rows;
    
    $sth->execute(@{$null_args[$i]})
	or next;
    my $r2 = $sth->fetchall_arrayref();
    my $n2 = $sth->rows;
    
    # Did we get back the expected "n"umber of rows?
    # Did we get back the specific "r"ows we expected as identifed by the key column?
    
    if (   $n1 == 1
	&& $n2 == 2
	&& $r1->[0][0] == 3
	&& $r2->[0][0] == 2
	&& $r2->[1][0] == 4)
    {
      print "=> WHERE clause style $i is supported.\n";
      push @ok, "$i: $sel[$i]";
    }
    else {
      print "=> WHERE clause style $i returned incorrect results.\n";
    }
}

$dbh->disconnect();

printf "\n%d styles are supported\n", scalar @ok;
print "$_\n" for @ok;
print "\n";
