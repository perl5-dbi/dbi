#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
eval "use Test::CVE";
plan skip_all => "Test::CVE required for this test" if $@;

has_no_cves ();
done_testing;
