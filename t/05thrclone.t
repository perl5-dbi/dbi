#!perl -w

# --- Test DBI support for threads created after the DBI was loaded

use strict;
use Config qw(%Config);

BEGIN {
    if (!$Config{useithreads} || $] < 5.008) {
	print "1..0 # Skipped: this perl $] not configured to support iThreads\n";
	exit 0;
    }
}

use threads;
use Test::More tests => 20;

# ---

use DBI;

#threads->create( sub { 1 } )->join; warn 2; exit 0;

$DBI::neat_maxlen = 12345;

sub tests1 {
  is($DBI::neat_maxlen, 12345);
}

my @thr;
foreach (1..10) {
    push @thr, threads->create( \&tests1 );
    tests1();
}
$_->join foreach @thr;

exit 0;
