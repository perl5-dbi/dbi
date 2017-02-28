#!perl -w
$|=1;

use strict;
use warnings;

require DBD::DBM;

use File::Path;
use File::Spec;
use Test::More;
use Cwd;
use Config qw(%Config);
use Storable qw(dclone);

my $using_dbd_gofer = ($ENV{DBI_AUTOPROXY}||'') =~ /^dbi:Gofer.*transport=/i;

use DBI;
use vars qw( @mldbm_types @dbm_types );

BEGIN {

    # 0=SQL::Statement if avail, 1=DBI::SQL::Nano
    # next line forces use of Nano rather than default behaviour
    # $ENV{DBI_SQL_NANO}=1;
    # This is done in zv*n*_50dbm_simple.t

    push @mldbm_types, '';
    if (eval { require 'MLDBM.pm'; }) {
	push @mldbm_types, qw(Data::Dumper Storable); # both in CORE
        push @mldbm_types, 'FreezeThaw'   if eval { require 'FreezeThaw.pm' };
        push @mldbm_types, 'YAML'         if eval { require MLDBM::Serializer::YAML; };
        push @mldbm_types, 'JSON'         if eval { require MLDBM::Serializer::JSON; };
    }

    # Potential DBM modules in preference order (SDBM_File first)
    # skip NDBM and ODBM as they don't support EXISTS
    my @dbms = qw(SDBM_File GDBM_File DB_File BerkeleyDB NDBM_File ODBM_File);
    my @use_dbms = @ARGV;
    if( !@use_dbms && $ENV{DBD_DBM_TEST_BACKENDS} ) {
	@use_dbms = split ' ', $ENV{DBD_DBM_TEST_BACKENDS};
    }

    if (lc "@use_dbms" eq "all") {
	# test with as many of the major DBM types as are available
        @dbm_types = grep { eval { local $^W; require "$_.pm" } } @dbms;
    }
    elsif (@use_dbms) {
	@dbm_types = @use_dbms;
    }
    else {
	# we only test SDBM_File by default to avoid tripping up
	# on any broken DBM's that may be installed in odd places.
	# It's only DBD::DBM we're trying to test here.
        # (However, if SDBM_File is not available, then use another.)
        for my $dbm (@dbms) {
            if (eval { local $^W; require "$dbm.pm" }) {
                @dbm_types = ($dbm);
                last;
            }
        }
    }

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

my $dbi_sql_nano = not DBD::DBM::Statement->isa('SQL::Statement');

do "./t/lib.pl";

my $dir = test_dir ();

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

print "Using DBM modules: @dbm_types\n";
print "Using MLDBM serializers: @mldbm_types\n" if @mldbm_types;

my %test_statements;
my %expected_results;

for my $columns ( 2 .. 3 )
{
    my $i = 0;
    my @tests = part { $i++ % 2 } @{ $tests_statement_results{$columns} };
    @{ $test_statements{$columns} } = @{$tests[0]};
    @{ $expected_results{$columns} } = @{$tests[1]};
}

unless (@dbm_types) {
    plan skip_all => "No DBM modules available";
}

for my $mldbm ( @mldbm_types ) {
    my $columns = ($mldbm) ? 3 : 2;
    for my $dbm_type ( @dbm_types ) {
	print "\n--- Using $dbm_type ($mldbm) ---\n";
        eval { do_test( $dbm_type, $mldbm, $columns) }
            or warn $@;
    }
}

done_testing();

sub do_test {
    my ($dtype, $mldbm, $columns) = @_;

    #diag ("Starting test: " . $starting_test_no);

    # The DBI can't test locking here, sadly, because of the risk it'll hang
    # on systems with broken NFS locking daemons.
    # (This test script doesn't test that locking actually works anyway.)

    # use f_lockfile in next release - use it here as test case only
    my $dsn ="dbi:DBM(RaiseError=0,PrintError=1):dbm_type=$dtype;dbm_mldbm=$mldbm;f_lockfile=.lck";

    if ($using_dbd_gofer) {
        $dsn .= ";f_dir=$dir";
    }

    my $dbh = DBI->connect( $dsn );

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
        eval {$dbh->{f_dir}=$dir};
        ok(!$@);
        eval {$dbh->{dbm_mldbm}=$mldbm};
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
        $sql =~ s/\S*fruit/${dtype}_fruit/; # include dbm type in table name
        $sql =~ s/;$//;
        #diag($sql);

        # XXX FIX INSERT with NULL VALUE WHEN COLUMN NOT NULLABLE
	$dtype eq 'BerkeleyDB' and !$mldbm and 0 == index($sql, 'INSERT') and $sql =~ s/NULL/''/;

        $sql =~ s/\s*;\s*(?:#(.*))//;
        my $comment = $1;

        my $sth = $dbh->prepare($sql);
        ok($sth, "prepare $sql") or diag($dbh->errstr || 'unknown error');

	my @bind;
	if($sth->{NUM_OF_PARAMS})
	{
	    @bind = split /,/, $comment;
	}
        # if execute errors we will handle it, not PrintError:
        $sth->{PrintError} = 0;
        my $n = $sth->execute(@bind);
        ok($n, 'execute') or diag($sth->errstr || 'unknown error');
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
    return 1;
}
1;
