#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

eval "use Test::Pod::Links";
plan skip_all => "Test::Pod::Links required for testing POD links" if $@;
Test::Pod::Links
    # https://github.com/skirmess/Test-Pod-Links/issues/1
    ->new (ignore => "https://stackoverflow.com/questions/tagged/dbi") # 403
    ->pod_file_ok ("DBI.pm");
done_testing ();
