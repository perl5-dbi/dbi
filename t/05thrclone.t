#!perl -w

# --- Test DBI support for threads created after the DBI was loaded

use strict;
use Config qw(%Config);

BEGIN {
    if (!$Config{useithreads} || $] < 5.008) {
	print "1..0 # Skipped: this $^O perl $] not configured to support iThreads\n";
	exit 0;
    }
}

use threads;
use Test::More tests => 10;

# ---

{
    package threads_sub;
    use base qw(threads);
}

use DBI;

$DBI::neat_maxlen = 12345;

my @connect_args = ("dbi:ExampleP:", '', '');

my $dbh_parent = DBI->connect_cached(@connect_args);
ok($dbh_parent);

sub tests1 {
  is($DBI::neat_maxlen, 12345);

  my $dbh = DBI->connect_cached(@connect_args);
  ok($dbh);
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

exit 0;
