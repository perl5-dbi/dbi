package DBI::Test::Case::DBI::simple::dbm;

use strict;
use warnings;

use parent qw(DBI::Test::DBI::Case);

use Data::Dumper;

use Test::More;
use DBI::Test;

sub filter_drivers
{
    my ( $self, $options, @test_dbds ) = @_;
    return grep { $_ eq "DBM" } @test_dbds;
}

BEGIN {
    if( eval { require List::MoreUtils; } )
    {
	List::MoreUtils->import("part");
    }
    else
    {
	# XXX from PP part of List::MoreUtils
	eval <<'EOP';
sub part(&@) {
    my ($code, @list) = @_;
    my @parts;
    push @{ $parts[$code->($_)] }, $_  for @list;
    return @parts;
}
EOP
    }
}

sub requires_extended { 1 }

my $dbi_sql_nano = not DBD::DBM::Statement->isa('SQL::Statement');
my $using_dbd_gofer = ( $ENV{DBI_AUTOPROXY} || '' ) =~ /^dbi:Gofer.*transport=/i;

my %tests_statement_results = (
    2 => [
	"DROP TABLE IF EXISTS fruit", -1,
	"CREATE TABLE fruit (dKey INT, dVal VARCHAR(10))", '0E0',
	"INSERT INTO  fruit VALUES (1,'oranges'   )", 1,
	"INSERT INTO  fruit VALUES (2,'to_change' )", 1,
	"INSERT INTO  fruit VALUES (3, NULL       )", 1,
	"INSERT INTO  fruit VALUES (4,'to delete' )", 1,
	"INSERT INTO  fruit VALUES (?,?); #5,via placeholders", 1,
	"INSERT INTO  fruit VALUES (6,'to delete' )", 1,
	"INSERT INTO  fruit VALUES (7,'to_delete' )", 1,
	"DELETE FROM  fruit WHERE dVal='to delete'", 2,
	"UPDATE fruit SET dVal='apples' WHERE dKey=2", 1,
	"DELETE FROM  fruit WHERE dKey=7", 1,
	"SELECT * FROM fruit ORDER BY dKey DESC", [
	    [ 5, 'via placeholders' ],
	    [ 3, '' ],
	    [ 2, 'apples' ],
	    [ 1, 'oranges' ],
	],
	"DELETE FROM fruit", 4,
	$dbi_sql_nano ? () : ( "SELECT COUNT(*) FROM fruit", [ [ 0 ] ] ),
	"DROP TABLE fruit", -1,
    ],
    3 => [
	"DROP TABLE IF EXISTS multi_fruit", -1,
	"CREATE TABLE multi_fruit (dKey INT, dVal VARCHAR(10), qux INT)", '0E0',
	"INSERT INTO  multi_fruit VALUES (1,'oranges'  , 11 )", 1,
	"INSERT INTO  multi_fruit VALUES (2,'to_change',  0 )", 1,
	"INSERT INTO  multi_fruit VALUES (3, NULL      , 13 )", 1,
	"INSERT INTO  multi_fruit VALUES (4,'to_delete', 14 )", 1,
	"INSERT INTO  multi_fruit VALUES (?,?,?); #5,via placeholders,15", 1,
	"INSERT INTO  multi_fruit VALUES (6,'to_delete', 16 )", 1,
	"INSERT INTO  multi_fruit VALUES (7,'to delete', 17 )", 1,
	"INSERT INTO  multi_fruit VALUES (8,'to remove', 18 )", 1,
	"UPDATE multi_fruit SET dVal='apples', qux='12' WHERE dKey=2", 1,
	"DELETE FROM  multi_fruit WHERE dVal='to_delete'", 2,
	"DELETE FROM  multi_fruit WHERE qux=17", 1,
	"DELETE FROM  multi_fruit WHERE dKey=8", 1,
	"SELECT * FROM multi_fruit ORDER BY dKey DESC", [
	    [ 5, 'via placeholders', 15 ],
	    [ 3, undef, 13 ],
	    [ 2, 'apples', 12 ],
	    [ 1, 'oranges', 11 ],
	],
	"DELETE FROM multi_fruit", 4,
	$dbi_sql_nano ? () : ( "SELECT COUNT(*) FROM multi_fruit", [ [ 0 ] ] ),
	"DROP TABLE multi_fruit", -1,
    ],
);


sub run_test
{
    use_ok("DBD::DBM") or plan skip_all => "No DBD::DBM tests without DBD::DBM";
    my @DB_CREDS = @{ $_[1] };

    my %test_statements;
    my %expected_results;

    my $columns = $DB_CREDS[3]->{dbm_mldbm} ? 3 : 2;
    my $i = 0;
    my @tests = part { $i++ % 2 } @{ $tests_statement_results{$columns} };
    @{ $test_statements{$columns} } = @{$tests[0]};
    @{ $expected_results{$columns} } = @{$tests[1]};


    $DB_CREDS[3]->{f_lockfile} = ".lck";

    my $dsn_str = Data::Dumper->new( [ \@DB_CREDS ] )->Indent(0)->Sortkeys(1)->Quotekeys(0)->Terse(1)->Dump();
    my $dbh = connect_ok(@DB_CREDS, "Connecting to ");

    my $dbm_versions;
    if ($DBI::VERSION >= 1.37   # needed for install_method
    && !$ENV{DBI_AUTOPROXY}     # can't transparently proxy driver-private methods
    ) {
        $dbm_versions = $dbh->dbm_versions;
    }
    else {
        $dbm_versions = $dbh->func('dbm_versions');
    }
    note $dbm_versions;
    ok($dbm_versions, 'dbm_versions');
    isa_ok($dbh, 'DBI::db');

    # test if it correctly accepts valid $dbh attributes
    SKIP: {
        skip "Can't set attributes after connect using DBD::Gofer", 2
            if $using_dbd_gofer;
        eval {$dbh->{f_dir} = $DB_CREDS[3]->{f_dir}};
        ok(!$@);
        eval {$dbh->{dbm_mldbm} = $DB_CREDS[3]->{dbm_mldbm}};
        ok(!$@);
    }

    # test if it correctly rejects invalid $dbh attributes
    #
    eval {
        local $SIG{__WARN__} = sub { } if $using_dbd_gofer;
        local $dbh->{RaiseError} = 1;
        local $dbh->{PrintError} = 0;
        $dbh->{dbm_bad_name}=1;
    };
    ok($@);

    my @queries = @{$test_statements{$columns}};
    my @results = @{$expected_results{$columns}};

    SKIP:
    for my $idx ( 0 .. $#queries ) {
	my $sql = $queries[$idx];
        $sql =~ s/;$//;

        # XXX FIX INSERT with NULL VALUE WHEN COLUMN NOT NULLABLE
	defined($DB_CREDS[3]->{dbm_type}) and $DB_CREDS[3]->{dbm_type} eq 'BerkeleyDB' and !defined($DB_CREDS[3]->{dbm_mldbm}) and 0 == index($sql, 'INSERT') and $sql =~ s/NULL/''/;

        $sql =~ s/\s*;\s*(?:#(.*))//;
        my $comment = $1;

        my $sth = prepare_ok($dbh, $sql, "prepare $sql") or diag($dbh->errstr || 'unknown error');

	my @bind;
	if($sth->{NUM_OF_PARAMS})
	{
	    @bind = split /,/, $comment;
	}
        # if execute errors we will handle it, not PrintError:
        $sth->{PrintError} = 0;
	my $bind_str = Data::Dumper->new( [ \@bind ] )->Indent(0)->Sortkeys(1)->Quotekeys(0)->Terse(1)->Dump();
        my $n = execute_ok($sth, @bind, "execute '$sql' with '$bind_str'") or diag($sth->errstr || 'unknown error');
        next if (!defined($n));

	is( $n, $results[$idx], $sql ) unless( 'ARRAY' eq ref $results[$idx] );
	TODO: {
	    local $TODO = "AUTOPROXY drivers might throw away sth->rows()" if($ENV{DBI_AUTOPROXY});
	    is( $n, $sth->rows, '$sth->execute(' . $sql . ') == $sth->rows' ) if( $sql =~ m/^(?:UPDATE|DELETE)/ );
	}
        next unless $sql =~ /SELECT/;
        my $results='';
	my $allrows = $sth->fetchall_arrayref();
	my $expected_rows = $results[$idx];
	is( $sth->rows, scalar( @{$expected_rows} ), $sql );
	is_deeply( $allrows, $expected_rows, 'SELECT results' );
    }

    my $sth = $dbh->table_info();
    ok ($sth, "prepare table_info (without tables)");
    my @tables = $sth->fetchall_arrayref;
    is_deeply( \@tables, [ [] ], "No tables delivered by table_info" );

    $dbh->disconnect;

    done_testing();
}

1;
