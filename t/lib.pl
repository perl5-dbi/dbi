#!/usr/bin/perl

# lib.pl is the file where database specific things should live,
# wherever possible. For example, you define certain constants
# here and the like.

use strict;

use File::Basename;
use File::Path;
use File::Spec;

my $test_dir;
END { defined( $test_dir ) and rmtree $test_dir }

sub test_dir
{
    unless( defined( $test_dir ) )
    {
	$test_dir = File::Spec->rel2abs( File::Spec->curdir () );
	$test_dir = File::Spec->catdir ( $test_dir, "test_output_" . $$ );
	$test_dir = VMS::Filespec::unixify($test_dir) if $^O eq 'VMS';
	rmtree $test_dir;
	mkpath $test_dir;
	# There must be at least one directory in the test directory,
	# and nothing guarantees that dot or dot-dot directories will exist.
	mkpath ( File::Spec->catdir( $test_dir, '000_just_testing' ) );
    }

    return $test_dir;
}

1;
