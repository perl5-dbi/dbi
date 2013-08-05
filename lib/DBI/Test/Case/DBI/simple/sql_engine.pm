package DBI::Test::Case::DBI::simple::sql_engine;

use strict;
use warnings;

use parent qw(DBI::Test::DBI::Case);

use Data::Dumper;

use Test::More;
use DBI::Test;

sub filter_drivers
{
    my ( $self, $options, @test_dbds ) = @_;
    return grep { $_ eq 'File' } @test_dbds;
}

sub run_test
{
    my @DB_CREDS = @{ $_[1] };

    # set HDF flag
    $DB_CREDS[3]->{PrintError} = 0;
    $DB_CREDS[3]->{RaiseError} = 0;

    my $dsn_str = Data::Dumper->new( [ \@DB_CREDS ] )->Indent(0)->Sortkeys(1)->Quotekeys(0)->Terse(1)->Dump();
    my $dbh = connect_ok( @DB_CREDS, "Connect to $dsn_str" );

    for my $sql ( split "\n", <<"" )
CREATE TABLE foo (id INT, foo TEXT)
CREATE TABLE bar (id INT, baz TEXT)
INSERT INTO foo VALUES (1, "Hello world")
INSERT INTO bar VALUES (1, "Bugfixes welcome")
INSERT bar VALUES (2, "Bug reports, too")
SELECT foo FROM foo where ID=1
UPDATE bar SET id=5 WHERE baz="Bugfixes welcome"
DELETE FROM foo
DELETE FROM bar WHERE baz="Bugfixes welcome"

    {
        my $sth;
        $sql =~ s/^\s+//;
        eval { $sth = $dbh->prepare($sql); };
        ok( $sth, "prepare '$sql'" );
    }

    for my $line ( split "\n", <<"" )
Junk -- Junk
CREATE foo (id INT, foo TEXT) -- missing table
INSERT INTO bar (1, "Bugfixes welcome") -- missing "VALUES"
UPDATE bar id=5 WHERE baz="Bugfixes welcome" -- missing "SET"
DELETE * FROM foo -- waste between "DELETE" and "FROM"

    {
        my $sth;
        $line =~ s/^\s+//;
        my ( $sql, $test ) = ( $line =~ m/^([^-]+)\s+--\s+(.*)$/ );
        eval { $sth = $dbh->prepare($sql); };
        ok( !$sth, "$test: prepare '$sql'" );
    }

  SKIP:
    {
        # some SQL::Statement / SQL::Parser related tests
        DBD::File::Statement->isa("SQL::Statement") or
        skip( "Not running with SQL::Statement", 3 );
        for my $line ( split "\n", <<"" )
	Junk -- Junk
	CREATE TABLE bar (id INT, baz CHARACTER VARYING(255)) -- invalid column type

        {
            my $sth;
            $line =~ s/^\s+//;
            my ( $sql, $test ) = ( $line =~ m/^([^-]+)\s+--\s+(.*)$/ );
            eval { $sth = $dbh->prepare($sql); };
            ok( !$sth, "$test: prepare '$sql'" );
        }

	$DB_CREDS[3]->{sql_dialect} = "ANSI";
	$dsn_str = Data::Dumper->new( [ \@DB_CREDS ] )->Indent(0)->Sortkeys(1)->Quotekeys(0)->Terse(1)->Dump();
	my $dbh2 = connect_ok( @DB_CREDS, "Connect to $dsn_str" );
        my $sth;
        eval {
            $sth = $dbh2->prepare(
                  "CREATE TABLE foo (id INTEGER PRIMARY KEY, phrase CHARACTER VARYING(40) UNIQUE)");
        };
        ok( $sth, "prepared statement using ANSI dialect" );
        skip( "Gofer proxy prevents fetching embedded SQL::Parser object", 1 );
        my $sql_parser = $dbh2->FETCH("sql_parser_object");
        cmp_ok( $sql_parser->dialect(), "eq", "ANSI", "SQL::Parser has 'ANSI' as dialect" );
    }

  SKIP:
    {
        skip( 'not running with DBIx::ContextualFetch', 2 )
          unless eval { require DBIx::ContextualFetch; 1; };

	$DB_CREDS[3]->{sql_dialect} = "ANSI";
	$dsn_str = Data::Dumper->new( [ \@DB_CREDS ] )->Indent(0)->Sortkeys(1)->Quotekeys(0)->Terse(1)->Dump();
	my $dbh2 = connect_ok( @DB_CREDS, "Connect to $dsn_str" );
        is ref $dbh2, 'DBIx::ContextualFetch::db', 'root class is DBIx::ContextualFetch';
    }

    done_testing();
}

1;
