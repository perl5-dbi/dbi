#!perl
use strict;
use DBI;
use File::Path;
use Test::More;
use vars qw( @mldbm_types @dbm_types );
BEGIN {
    use lib qw(./ ../../lib);

    # 0=SQL::Statement if avail, 1=DBI::SQL::Nano
    # uncomment next line to force use of Nano rather than default behaviour
    # $ENV{DBI_SQL_NANO}=1;

    # test without MLDBM
    # also test with MLDBM if both it and Data::Dumper are available
    #
    @mldbm_types = ('plain');
    eval { require 'MLDBM.pm'; require 'Data/Dumper.pm' };
    push @mldbm_types, 'mldbm' unless $@;

    # test with as many of the 5 major DBM types as are available
    #
    for (qw( SDBM_File GDBM_File NDBM_File ODBM_File DB_File BerkeleyDB )){
        undef $@;
        eval { require "$_.pm" };
        push @dbm_types, $_ unless $@;
    }

    my $num_tests = @mldbm_types * @dbm_types * 11;
    if (!$num_tests) {
        plan tests => 1;
        SKIP: {
            skip("No DBM modules available",1);
        }
        exit;
    }
    else {
        plan tests => $num_tests;
    }
}
my $dir = './test_output';
rmtree $dir;
mkpath $dir;
my( $two_col_sql,$three_col_sql ) = split /\n\n/,join '',<DATA>;
my %sql = (
    mldbm => [ split /\s*;\n/, $three_col_sql ]
  , plain => [ split /\s*;\n/, $two_col_sql   ]
);
for my $mldbm ( @mldbm_types ) {
    for my $dbm_type ( @dbm_types ) {
        do_test( $dbm_type, $sql{$mldbm}, $mldbm );
    }
}
rmtree $dir;

sub do_test {
    my $dtype = shift;
    my $stmts = shift;
    my $mldbm = shift;
    $|=1;
    my $ml = ''  if $mldbm eq 'plain';
       $ml = 'D' if $mldbm eq 'mldbm';
    my $dsn ="dbi:DBM(RaiseError=1,PrintError=0):dbm_type=$dtype;mldbm=$ml";
    my $dbh = DBI->connect( $dsn );
    if ($DBI::VERSION >= 1.37 ) { # needed for install_method
        diag( $dbh->dbm_versions );
    }
    else {
        diag( $dbh->func('dbm_versions') );
    }
    ok($dbh);

    # test if it correctly accepts valid $dbh attributes
    #
    eval {$dbh->{f_dir}=$dir};
    ok(!$@);
    eval {$dbh->{dbm_mldbm}=$ml};
    ok(!$@);

    # test if it correctly rejects invalid $dbh attributes
    #
    eval {$dbh->{dbm_bad_name}=1};
    ok($@);

    for my $sql ( @$stmts ) {
        $sql =~ s/\S*fruit/${dtype}_fruit/; # include dbm type in table name
        $sql =~ s/;$//;  # in case no final \n on last line of __DATA__
        #diag($sql);
        my $null = '';
        my $expected_results = {
            1 => 'oranges',
            2 => 'apples',
            3 => $null,
        };
        $expected_results = {
            1 => '11',
            2 => '12',
            3 => '13',
        } if $ml;
        my $sth = $dbh->prepare($sql) or die $dbh->errstr;
        $sth->execute;
        die $sth->errstr if $sth->errstr and $sql !~ /DROP/;
        next unless $sql =~ /SELECT/;
        my $results='';
        # Note that we can't rely on the order here, it's not portable,
        # different DBMs (or versions) will return different orders.
        while (my ($key, $value) = $sth->fetchrow_array) {
            ok exists $expected_results->{$key};
            is $value, $expected_results->{$key};
        }
        is $DBI::rows, keys %$expected_results;
    }
    $dbh->disconnect;
}
1;
__DATA__
DROP TABLE IF EXISTS fruit;
CREATE TABLE fruit (dKey INT, dVal VARCHAR(10));
INSERT INTO  fruit VALUES (1,'oranges'   );
INSERT INTO  fruit VALUES (2,'to_change' );
INSERT INTO  fruit VALUES (3, NULL       );
INSERT INTO  fruit VALUES (4,'to_delete' );
UPDATE fruit SET dVal='apples' WHERE dKey=2;
DELETE FROM  fruit WHERE dKey=4;
SELECT * FROM fruit;
DROP TABLE fruit;

DROP TABLE IF EXISTS multi_fruit;
CREATE TABLE multi_fruit (dKey INT, dVal VARCHAR(10), qux INT);
INSERT INTO  multi_fruit VALUES (1,'oranges'  , 11 );
INSERT INTO  multi_fruit VALUES (2,'apples'   ,  0 );
INSERT INTO  multi_fruit VALUES (3, NULL      , 13 );
INSERT INTO  multi_fruit VALUES (4,'to_delete', 14 );
UPDATE multi_fruit SET qux='12' WHERE dKey=2;
DELETE FROM  multi_fruit WHERE dKey=4;
SELECT dKey,qux FROM multi_fruit;
DROP TABLE multi_fruit;


