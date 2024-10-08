#!/usr/bin/perl

use strict;
use warnings;

eval "use Test::More 0.93";
if ($@ || $] < 5.010) {
    print "1..0 # perl-5.10.0 + Test::More 0.93 required for version checks\n";
    exit 0;
    }
eval "use Test::MinimumVersion";
if ($@) {
    print "1..0 # Test::MinimumVersion required for compatability tests\n";
    exit 0;
    }

my @pm = sort "DBI.pm",
	(glob "lib/*/*.pm"),
	(glob "lib/*/*/*.pm"),
	(glob "lib/*/*/*/*.pm");

my %f5xx = (
    "5.008.1" => { map { $_ => 1 } @pm, glob ("t/*"), glob ("xt/*.t"), glob ("*.PL") },
    "5.010.0" => {},
    "5.012.0" => {},
    "5.014.0" => { map { $_ => 1 } "xt/20_kwalitee.t" },
    "5.016.0" => {},
    );

my @v = sort keys %f5xx;
foreach my $v (reverse @v) {
    foreach my $f (sort keys %{$f5xx{$v}}) {
	foreach my $x (grep { $_ lt $v } @v) {
	    delete $f5xx{$x}{$f}
	    }
	}
    }

foreach my $v (@v) {
    my @f = sort keys %{$f5xx{$v}} or next;
    subtest ($v => sub { all_minimum_version_ok ($v, { paths => [ @f ]}); });
    }

done_testing ();
