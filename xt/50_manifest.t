#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

eval "use Test::DistManifest";
plan skip_all => "Test::DistManifest required for testing MANIFEST" if $@;
manifest_ok ();
done_testing;
