#!perl

use strict;
use warnings;

use Test::More tests => 11;

## ----------------------------------------------------------------------------
## 07kids.t
## ----------------------------------------------------------------------------
# This test check the Kids and the ActiveKids attributes
# NOTE:
# there is likely more I can do here, I just need to figure out what
## ----------------------------------------------------------------------------

## load DBI

BEGIN {
	use_ok('DBI');
}

SKIP: {
	skip '$h->{Kids} attribute not supported for DBI::PurePerl', 10 if ($DBI::PurePerl);

	# Connect to the example driver.
	my $dbh = DBI->connect('dbi:ExampleP:dummy', '', '',
							   { PrintError => 0,
								 RaiseError => 0,
								 HandleError => \&test_kid
							   });
	ok($dbh, '... got a database handle');
	isa_ok($dbh, 'DBI::db');

	# Raise an error.
	my $x = eval { $dbh->do('select foo from foo') };
	
	cmp_ok($dbh->{Kids}, '==', 0, '... database handle has 0 Kid(s)');

	my $drh = $dbh->{Driver};
	cmp_ok( $drh->{Kids}, '==', 1, '... driver handle has 1 Kid(s)');
	cmp_ok( $drh->{ActiveKids}, '==', 1, '... database handle has 1 ActiveKid(s)');

	$dbh->disconnect;
	cmp_ok( $drh->{Kids}, '==', 1, '... driver handle has 1 Kid(s) after $dbh->disconnect');
	cmp_ok( $drh->{ActiveKids}, '==', 0, '... database handle has 0 ActiveKid(s) after $dbh->disconnect');

	undef $dbh;
	cmp_ok( $drh->{Kids}, '==', 0, '... driver handle has 0 Kid(s) after undef $dbh');
	cmp_ok( $drh->{ActiveKids}, '==', 0, '... database handle has 0 ActiveKid(s) after undef $dbh');	
}

sub test_kid {
    my ($err, $dbh, $retval) = @_;
    # Testing $dbh->{Kids} here is unstable because we would be relying on
    # when perl chooses to call DESTROY the lexical $sth created within prepare()
    # The HandleError sub doesn't get called until the do() is returning
    # and recent perl's (>=5.8.0) have destroyed the handle by then (quite reasonably).

    # When a HandleEvent attribute gets added to the DBI then we'll probably call that
    # at the moment the error is registered, and so we could test $sth->{Kids} then.

    pass('... test_kid error handler running');
}

1;
