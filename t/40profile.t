#!perl -w
use strict;

#
# test script for DBI::Profile
# 
# TODO:
#
# - fix dbi_profile, see below for test that produces a warning
#   and doesn't work as expected
# 
# - add tests for the undocumented dbi_profile_merge
#

use DBI;
use DBI::Profile;
use File::Spec;
use Config;

BEGIN {
    if ($DBI::PurePerl) {
	print "1..0 # Skipped: profiling not supported for DBI::PurePerl\n";
	exit 0;
    }
}

use Test;
BEGIN { plan tests => 57; }

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Terse = 1;

# log file to store profile results 
my $LOG_FILE = "profile.log";
DBI->trace(0, $LOG_FILE);
END { 1 while unlink $LOG_FILE; }

# make sure profiling starts disabled
my $dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1 });
ok($dbh);
ok(!$dbh->{Profile} && !$ENV{DBI_PROFILE});
$dbh->disconnect;
undef $dbh;

# can turn it on after the fact using a path number
$dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1 });
$dbh->{Profile} = "4";
ok(ref $dbh->{Profile}, "DBI::Profile");
ok(ref $dbh->{Profile}{Data}, 'HASH');
ok(ref $dbh->{Profile}{Path}, 'ARRAY');
$dbh->disconnect;
undef $dbh;

# using a package name
$dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1 });
$dbh->{Profile} = "DBI::Profile";
ok(ref $dbh->{Profile}, "DBI::Profile");
ok(ref $dbh->{Profile}{Data}, 'HASH');
ok(ref $dbh->{Profile}{Path}, 'ARRAY');
undef $dbh;

# using a combined path and name
$dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1 });
$dbh->{Profile} = "2/DBI::Profile";
ok(ref $dbh->{Profile}, "DBI::Profile");
ok(ref $dbh->{Profile}{Data}, 'HASH');
ok(ref $dbh->{Profile}{Path}, 'ARRAY');
undef $dbh;

# can turn it on at connect
$dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1, Profile=>2 });
ok(ref $dbh->{Profile}, "DBI::Profile");
ok(ref $dbh->{Profile}{Data}, 'HASH');
ok(ref $dbh->{Profile}{Path}, 'ARRAY');

# do a (hopefully) measurable amount of work
my $sql = "select mode,size,name from ?";
my $sth = $dbh->prepare($sql);
for my $loop (1..50) { # enough work for low-res timers or v.fast cpus
    $sth->execute(".");
    while ( my $hash = $sth->fetchrow_hashref ) {}
}

print Dumper($dbh->{Profile});

# check that the proper key was set in Data
my $data = $dbh->{Profile}{Data}{$sql};
ok($data);
ok(ref $data, 'ARRAY');
ok(@$data == 7);
ok((grep { defined($_)                } @$data) == 7);
ok((grep { DBI::looks_like_number($_) } @$data) == 7);
ok((grep { $_ >= 0                    } @$data) == 7) or warn "profile data: [@$data]\n";
my ($count, $total, $first, $shortest, $longest, $time1, $time2) = @$data;
if ($shortest < 0) {
    warn "Time went backwards at some point during the test on this $Config{archname} system!\n";
    warn "Perhaps you have time sync software (like NTP) that adjusted the clock\n";
    warn "backwards by more than $shortest seconds during the test.\n";
}
ok($count > 3);
ok($total > $first);
ok($total > $longest) or warn "total $total > longest $longest: failed\n";
ok($longest > 0) or warn "longest $longest > 0: failed\n"; # XXX theoretically not reliable
ok($longest > $shortest);
ok($time1 > 0);
ok($time2 > 0);
my $next = time + 1;
ok($next > $time1) or warn "next $next > first $time1: failed\n";
ok($next > $time2) or warn "next $next > last $time2: failed\n";
ok($time1 <= $time2);

# collect output
my $output = $dbh->{Profile}->format();
print "Profile Output\n\n$output";

# check that output was produced in the expected format
ok(length $output);
ok($output =~ /^DBI::Profile:/);
ok($output =~ /\((\d+) method calls\)/);
ok($1 >= $count);

# try statement and method name path
$dbh = DBI->connect("dbi:ExampleP:", '', '', 
                    { RaiseError => 1, 
                      Profile    => 6 });
ok(ref $dbh->{Profile}, "DBI::Profile");
ok(ref $dbh->{Profile}{Data}, 'HASH');
ok(ref $dbh->{Profile}{Path}, 'ARRAY');

# do a little work
$sql = "select name from .";
$sth = $dbh->prepare($sql);
$sth->execute();
while ( my $hash = $sth->fetchrow_hashref ) {}

# check that the resulting tree fits the expected layout
$data = $dbh->{Profile}{Data};
ok($data);
ok(exists $data->{$sql});
ok(keys %{$data->{$sql}} == 3);
ok(exists $data->{$sql}{prepare});
ok(exists $data->{$sql}{execute});
ok(exists $data->{$sql}{fetchrow_hashref});



# try a custom path
$dbh = DBI->connect("dbi:ExampleP:", '', '', 
                    { RaiseError=>1, 
                      Profile=> { Path => [ 'foo',
                                            DBIprofile_Statement, 
                                            DBIprofile_MethodName, 
                                            'bar' ]}});
ok(ref $dbh->{Profile}, "DBI::Profile");
ok(ref $dbh->{Profile}{Data}, 'HASH');
ok(ref $dbh->{Profile}{Path}, 'ARRAY');

# do a little work
$sql = "select name from .";
$sth = $dbh->prepare($sql);
$sth->execute();
while ( my $hash = $sth->fetchrow_hashref ) {}

# check that the resulting tree fits the expected layout
$data = $dbh->{Profile}{Data};
ok($data);
ok(exists $data->{foo});
ok(exists $data->{foo}{$sql});
ok(exists $data->{foo}{$sql}{prepare});
ok(exists $data->{foo}{$sql}{execute});
ok(exists $data->{foo}{$sql}{fetchrow_hashref});
ok(exists $data->{foo}{$sql}{prepare}{bar});
ok(ref $data->{foo}{$sql}{prepare}{bar}, 'ARRAY');
ok(@{$data->{foo}{$sql}{prepare}{bar}} == 7);

my $t1 = DBI::dbi_time;
dbi_profile($dbh, "Hi, mom", "fetchhash_bang", $t1, $t1 + 1);
ok(exists $data->{foo}{"Hi, mom"});

# check that output went into the log file
DBI->trace(0, "STDOUT"); # close current log to flush it
ok(-s $LOG_FILE);

exit 0;
