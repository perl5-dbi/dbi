#!perl -w

# --- Test DBI support for threads created after the DBI was loaded

use strict;
use Config qw(%Config);

BEGIN {
    use Test::More;
	if (!$Config{useithreads} || $] < 5.008) {
		plan skip_all => "this $^O perl $] not configured to support iThreads";
	}
}

use threads;
use Test::More tests => 11;

{
    package threads_sub;
    use base qw(threads);
}

BEGIN {
	use_ok('DBI');
}

$DBI::neat_maxlen = 12345;
cmp_ok($DBI::neat_maxlen, '==', 12345, '... assignment of neat_maxlen was successful');

my @connect_args = ("dbi:ExampleP:", '', '');

my $dbh_parent = DBI->connect_cached(@connect_args);
isa_ok( $dbh_parent, 'DBI::db' );

# this our function for the threads to run

sub testing {
    cmp_ok($DBI::neat_maxlen, '==', 12345, '... DBI::neat_maxlen still holding its value');

    my $dbh = DBI->connect_cached(@connect_args);
    isa_ok( $dbh, 'DBI::db' );
    isnt($dbh, $dbh_parent, '... new $dbh is not the same instance as $dbh_parent');
 
    SKIP: {
        skip "Kids attribute not supported under DBI::PurePerl", 1 if $DBI::PurePerl;
        
        cmp_ok($dbh->{Driver}->{Kids}, '==', 1, '... the Driver has one Kid');
    }
}

# load up the threads

my @thr;
push @thr, threads_sub->create( \&testing ) foreach (1..2);

# join all the threads

foreach my $thread (@thr) {
    $thread->join;
}

pass('... all tests have passed');

1;
