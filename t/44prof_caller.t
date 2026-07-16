#!perl -w
$|=1;

#
# test that DBI::Profile !Caller2 still reports the caller's caller when
# $^P is set but &DB::sub is not defined, as happens under tools such as
# Devel::Cover (GH #177)
#

use strict;

use DBI;
use File::Basename qw(basename);

use Test::More;

BEGIN {
    plan skip_all => "profiling not supported for DBI::PurePerl"
        if $DBI::PurePerl;

    plan tests => 2;
}

# log file to store profile results
my $LOG_FILE = "test_output_profile$$.log";
my $orig_dbi_debug = $DBI::dbi_debug;
DBI->trace($DBI::dbi_debug, $LOG_FILE);
END {
    return if $orig_dbi_debug;
    1 while unlink $LOG_FILE;
}

# simulate a tool like Devel::Cover: the debugger API is initialised
# because $^P is set, but &DB::sub is not defined
$^P |= 0x100;

our $dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1 });
$dbh->{Profile} = "!MethodName:!Caller2";

# the "via ..." part of !Caller2 needs the profiled call to be made
# inside a sub, eval or do FILE, so call $dbh->do from a helper file
my $helper_file = "test_output_dbsub$$.pl";
END { 1 while defined $helper_file && unlink $helper_file }
open my $fh, ">", $helper_file or die "Can't create $helper_file: $!";
print $fh qq{\$main::dbh->do("set foo=1");\n1;\n};
close $fh or die "Can't close $helper_file: $!";

do "./$helper_file" or die $@ || $!; my $line = __LINE__;

my @keys = keys %{ $dbh->{Profile}{Data}{do} };
is scalar @keys, 1, 'one profile leaf for do';
my $this_file = basename(__FILE__);
is $keys[0], "$helper_file line 1 via $this_file line $line",
    '!Caller2 includes the "via" caller when $^P is set';

$dbh->{Profile} = 0;

1;
