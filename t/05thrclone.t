#!perl -w

# --- Test DBI support for threads created after the DBI was loaded

use strict;
use Config qw(%Config);

use Test::More;

BEGIN {
	if (!$Config{useithreads} || $] < 5.008) {
		plan skip_all => "this $^O perl $] not configured to support iThreads";
	}
	else {
		plan tests => 11;
	}
}

BEGIN {
	use_ok('DBI');
}

use threads;

{
    package threads_sub;
    use base qw(threads);
}

$DBI::neat_maxlen = 12345;

my @connect_args = ("dbi:ExampleP:", '', '');

my $dbh_parent = DBI->connect_cached(@connect_args);
isa_ok( $dbh_parent, 'DBI::db' );

sub tests1 {
  is($DBI::neat_maxlen, 12345);

  my $dbh = DBI->connect_cached(@connect_args);
  isa_ok( $dbh, 'DBI::db' );
  isnt($dbh, $dbh_parent);
  is($dbh->{Driver}->{Kids}, 1) unless $DBI::PurePerl && ok(1);
}

my @thr;
foreach (1..2) {
    print "\n\n*** creating thread $_\n";
    push @thr, threads_sub->create( \&tests1 );
}
foreach (@thr) {
    print "\n\n*** joining thread $_\n";
    $_->join;
}

ok(1);

1;
