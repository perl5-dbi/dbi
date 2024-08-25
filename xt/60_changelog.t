#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

eval "use Test::CPAN::Changes";
plan skip_all => "Test::CPAN::Changes required for this test" if $@;

changes_file_ok ("Changes");

done_testing;
