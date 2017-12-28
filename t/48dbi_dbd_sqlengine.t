#!perl -w
$|=1;

use strict;

use Cwd;
use File::Path;
use File::Spec;
use Test::More;

my $using_dbd_gofer = ($ENV{DBI_AUTOPROXY}||"") =~ /^dbi:Gofer.*transport=/i;

my $tbl;
BEGIN { $tbl = "db_". $$ . "_" };
#END   { $tbl and unlink glob "${tbl}*" }

use_ok ("DBI");
use_ok ("DBI::DBD::SqlEngine");
use_ok ("DBD::File");

my $sql_statement = DBI::DBD::SqlEngine::Statement->isa('SQL::Statement');
my $dbh = DBI->connect( "DBI:File:", undef, undef, { PrintError => 0, RaiseError => 0, } ); # Can't use DBI::DBD::SqlEngine direct

for my $sql ( split "\n", <<"" )
    CREATE TABLE foo (id INT, foo TEXT)
    CREATE TABLE bar (id INT, baz TEXT)
    INSERT INTO foo VALUES (1, 'Hello world')
    INSERT INTO bar VALUES (1, 'Bugfixes welcome')
    INSERT bar VALUES (2, 'Bug reports, too')
    SELECT foo FROM foo where ID=1
    UPDATE bar SET id=5 WHERE baz='Bugfixes welcome'
    DELETE FROM foo
    DELETE FROM bar WHERE baz='Bugfixes welcome'

{
    my $sth;
    $sql =~ s/^\s+//;
    eval { $sth = $dbh->prepare( $sql ); };
    ok( $sth, "prepare '$sql'" );
}

for my $line ( split "\n", <<"" )
    Junk -- Junk
    CREATE foo (id INT, foo TEXT) -- missing table
    INSERT INTO bar (1, 'Bugfixes welcome') -- missing "VALUES"
    UPDATE bar id=5 WHERE baz="Bugfixes welcome" -- missing "SET"
    DELETE * FROM foo -- waste between "DELETE" and "FROM"

{
    my $sth;
    $line =~ s/^\s+//;
    my ($sql, $test) = ( $line =~ m/^([^-]+)\s+--\s+(.*)$/ );
    eval { $sth = $dbh->prepare( $sql ); };
    ok( !$sth, "$test: prepare '$sql'" );
}

SKIP: {
    # some SQL::Statement / SQL::Parser related tests
    skip( "Not running with SQL::Statement", 3 ) unless ($sql_statement);
    for my $line ( split "\n", <<"" )
	Junk -- Junk
	CREATE TABLE bar (id INT, baz CHARACTER VARYING(255)) -- invalid column type

    {
	my $sth;
	$line =~ s/^\s+//;
	my ($sql, $test) = ( $line =~ m/^([^-]+)\s+--\s+(.*)$/ );
	eval { $sth = $dbh->prepare( $sql ); };
	ok( !$sth, "$test: prepare '$sql'" );
    }

    my $dbh2 = DBI->connect( "DBI:File:", undef, undef, { sql_dialect => "ANSI" } );
    my $sth;
    eval { $sth = $dbh2->prepare( "CREATE TABLE foo (id INTEGER PRIMARY KEY, phrase CHARACTER VARYING(40) UNIQUE)" ); };
    ok( $sth, "prepared statement using ANSI dialect" );
    skip( "Gofer proxy prevents fetching embedded SQL::Parser object", 1 );
    my $sql_parser = $dbh2->FETCH("sql_parser_object");
    cmp_ok( $sql_parser->dialect(), "eq", "ANSI", "SQL::Parser has 'ANSI' as dialect" );
}

SKIP: {
    skip( 'not running with DBIx::ContextualFetch', 2 )
	unless eval { require DBIx::ContextualFetch; 1; };

    my $dbh;

    ok ($dbh = DBI->connect('dbi:File:','','', {RootClass => 'DBIx::ContextualFetch'}));
    is ref $dbh, 'DBIx::ContextualFetch::db', 'root class is DBIx::ContextualFetch';
}

done_testing ();
