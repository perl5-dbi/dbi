#!perl -w

use strict;
use Test::More tests => 41;

use Data::Dumper;
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse = 1;

BEGIN {
	use_ok('DBI');
}

my $dbh = DBI->connect("dbi:Sponge:dummy", '', '', { RaiseError=>1, AutoCommit=>1 });
ok($dbh);
isa_ok($dbh, "DBI::db");

my $rows = [ ];
my $tuple_status = [];
my $dumped;

#$dbh->trace(2);

my $sth = $dbh->prepare("insert", {
	rows => $rows,		# where to 'insert' (push) the rows
	NUM_OF_PARAMS => 4,
	# DBD::Sponge hook to make certain data trigger an error for that row
	execute_hook => sub {
	    local $^W;
	    return $_[0]->set_err(1,"errmsg")
		if grep { $_ and $_ eq "B" } @_;
	    return 1;
	},
});
ok($sth);

cmp_ok(scalar @{$rows}, '==', 0);
ok(!$sth->execute_array( { ArrayTupleStatus => $tuple_status },
	[ 1, 2, 3 ],	# array of integers
	42,		# scalar 42 treated as array of 42's
	undef,		# scalar undef treated as array of undef's
	[ qw(A B C) ],	# array of strings
    )
);

cmp_ok(scalar @{$rows}, '==', 2);
cmp_ok(scalar @{$tuple_status}, '==', 3);

$dumped = Dumper($rows);
is( $dumped, "[[1,42,undef,'A'],[3,42,undef,'C']]");	# missing row containing B

$dumped = Dumper($tuple_status);
is( $dumped, "[1,[1,'errmsg','S1000'],1]");		# row containing B has error


# --- change one param and re-execute

@$rows = ();
ok( $sth->bind_param_array(4, [ qw(a b c) ]) );
ok( $sth->execute_array({ ArrayTupleStatus => $tuple_status }) );

cmp_ok(scalar @{$rows}, '==', 3);
cmp_ok(scalar @{$tuple_status}, '==', 3);

$dumped = Dumper($rows);
ok( $dumped, "[[1,42,undef,'a'],[2,42,undef,'b'],[3,42,undef,'c']]");

$dumped = Dumper($tuple_status);
ok( $dumped, "[1,1,1]");

# --- with no values for bind params, should execute zero times

@$rows = ();
cmp_ok( $sth->execute_array( { ArrayTupleStatus => $tuple_status },
        [], [], [], [],
    ),
	'==', 0);
cmp_ok(scalar @{$rows}, '==', 0);
cmp_ok(scalar @{$tuple_status}, '==', 0);

# --- catch 'undefined value' bug with zero bind values

@$rows = ();
my $sth_other = $dbh->prepare("insert", {
	rows => $rows,		# where to 'insert' (push) the rows
	NUM_OF_PARAMS => 1,
});
cmp_ok( $sth_other->execute_array( {}, [] ), '==', 0); # no ArrayTupleStatus
cmp_ok(scalar @{$rows}, '==', 0);

# --- ArrayTupleFetch code-ref tests ---

my $index = 0;
my $fetchrow = sub { # generate 5 rows of two integer values
    return if $index >= 2;
    $index +=1;
    # There doesn't seem any reliable way to force $index to be
    # treated as a string (and so dumped as such).  We just have to
    # make the test case allow either 1 or '1'.
    #
    return [ $index, 'a','b','c' ];
};
@$rows = ();
ok( $sth->execute_array({
	ArrayTupleFetch  => $fetchrow,
	ArrayTupleStatus => $tuple_status,
}) );
cmp_ok(scalar @{$rows}, '==', 2);
cmp_ok(scalar @{$tuple_status}, '==', 2);
$dumped = Dumper($rows);
$dumped =~ s/'(\d)'/$1/g;
ok( $dumped, "[[1,'a','b','c'],[2,'a','b','c']]");
$dumped = Dumper($tuple_status);
ok( $dumped, "[1,1]");

# --- ArrayTupleFetch sth tests ---

my $fetch_sth = $dbh->prepare("foo", {
        rows => [ map { [ $_,'x','y','z' ] } 7..9 ],
        NUM_OF_FIELDS =>4
        #NAME => 
});
$fetch_sth->execute();
@$rows = ();
ok( $sth->execute_array({
	ArrayTupleFetch  => $fetch_sth,
	ArrayTupleStatus => $tuple_status,
}) );
cmp_ok(scalar @{$rows}, '==', 3);
cmp_ok(scalar @{$tuple_status}, '==', 3);
$dumped = Dumper($rows);
ok( $dumped, "[[7,'x','y','z'],[8,'x','y','z'],[9,'x','y','z']]");
$dumped = Dumper($tuple_status);
ok( $dumped, "[1,1,1]");

# --- error detection tests ---

$sth->{RaiseError} = 0;
$sth->{PrintError} = 0;
#$sth->trace(2);

is( $sth->execute_array( { ArrayTupleStatus => $tuple_status }, [1],[2]), undef );
is( $sth->errstr, '2 bind values supplied but 4 expected' );

is( $sth->execute_array( { ArrayTupleStatus => { } }, [ 1, 2, 3 ]), undef );
is( $sth->errstr, 'ArrayTupleStatus attribute must be an arrayref' );

is( $sth->execute_array( { ArrayTupleStatus => $tuple_status }, 1,{},3,4), undef );
is( $sth->errstr, 'Value for parameter 2 must be a scalar or an arrayref, not a HASH' );

is( $sth->execute_array( { ArrayTupleStatus => $tuple_status }, 1,[1],[2,2],3), undef );
is( $sth->errstr, 'Arrayref for parameter 3 has 2 elements but parameter 2 has 1' );

is( $sth->bind_param_array(":foo", [ qw(a b c) ]), undef );
is( $sth->errstr, "Can't use named placeholders for non-driver supported bind_param_array");

