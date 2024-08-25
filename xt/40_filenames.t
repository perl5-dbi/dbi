#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

eval "use Test::Portability::Files";
plan skip_all => "1..0 # Test::Portability::Files required for these tests\n" if $@;

BEGIN { $ENV{RELEASE_TESTING} = 1; }

options (use_file_find => 0, test_amiga_length => 1, test_mac_length => 1);
run_tests ();
