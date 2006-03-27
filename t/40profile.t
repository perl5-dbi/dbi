#!perl -w

#
# test script for DBI::Profile
# 

use strict;

use Config;
use DBI::Profile;
use DBI;
use Data::Dumper;
use File::Spec;
use Storable qw(dclone);

BEGIN {
    if ($DBI::PurePerl) {
	print "1..0 # Skipped: profiling not supported for DBI::PurePerl\n";
	exit 0;
    }
}

use Test::More tests => 36;

$Data::Dumper::Indent = 1;
$Data::Dumper::Terse = 1;

# log file to store profile results 
my $LOG_FILE = "profile.log";
DBI->trace(0, $LOG_FILE);
END { 1 while unlink $LOG_FILE; }


print "Test enabling the profile\n";

# make sure profiling starts disabled
my $dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1 });
ok($dbh);
ok(!$dbh->{Profile} && !$ENV{DBI_PROFILE});


# can turn it on after the fact using a path number
$dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1 });
$dbh->{Profile} = "4";
is_deeply sanitize_tree($dbh->{Profile}), bless {
	'Path' => [ DBIprofile_MethodName ],
} => 'DBI::Profile';

# using a package name
$dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1 });
$dbh->{Profile} = "DBI::Profile";
is_deeply sanitize_tree($dbh->{Profile}), bless {
	'Path' => [ DBIprofile_Statement ],
} => 'DBI::Profile';

# using a combined path and name
$dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1 });
$dbh->{Profile} = "20/DBI::Profile";
$dbh->do("set foo=1"); my $line = __LINE__;
is_deeply sanitize_tree($dbh->{Profile}), bless {
	'Path' => [ DBIprofile_MethodName, DBIprofile_Caller ],
	'Data' => { 'do' => {
		"40profile.t line $line" => [ 1, 0, 0, 0, 0, 0, 0 ]
	} }
} => 'DBI::Profile';
#die Dumper $dbh->{Profile};


# can turn it on at connect
$dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1, Profile=>6 });
is_deeply sanitize_tree($dbh->{Profile}), bless {
	'Path' => [ DBIprofile_Statement, DBIprofile_MethodName ],
	'Data' => {
		'' => {
			'FETCH' => [ 1, 0, 0, 0, 0, 0, 0 ],
			'STORE' => [ 2, 0, 0, 0, 0, 0, 0 ]
		}
	}
} => 'DBI::Profile';

print "dbi_profile\n";
my $t1 = DBI::dbi_time;
dbi_profile($dbh, "Hi, mom", "my_method_name", $t1, $t1 + 1);
is_deeply sanitize_tree($dbh->{Profile}), bless {
	'Path' => [ DBIprofile_Statement, DBIprofile_MethodName ],
	'Data' => {
		'' => {
			'FETCH' => [ 1, 0, 0, 0, 0, 0, 0 ], # +0
			'STORE' => [ 2, 0, 0, 0, 0, 0, 0 ]
		},
		"Hi, mom" => {
			my_method_name => [ 1, 0, 0, 0, 0, 0, 0 ],
		},
	}
} => 'DBI::Profile';

my $mine = $dbh->{Profile}{Data}{"Hi, mom"}{my_method_name};
print "@$mine\n";
is_deeply $mine, [ 1, 1, 1, 1, 1, $t1, $t1 ];

my $t2 = DBI::dbi_time;
dbi_profile($dbh, "Hi, mom", "my_method_name", $t2, $t2 + 2);
print "@$mine\n";
is_deeply $mine, [ 2, 3, 1, 1, 2, $t1, $t2 ];


print "Test collected profile data\n";

$dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1, Profile=>2 });
# do a (hopefully) measurable amount of work
my $sql = "select mode,size,name from ?";
my $sth = $dbh->prepare($sql);
for my $loop (1..50) { # enough work for low-res timers or v.fast cpus
    $sth->execute(".");
    while ( my $hash = $sth->fetchrow_hashref ) {}
}
$dbh->do("set foo=1");

print Dumper($dbh->{Profile});

# check that the proper key was set in Data
my $data = $dbh->{Profile}{Data}{$sql};
ok($data);
is(ref $data, 'ARRAY');
ok(@$data == 7);
ok((grep { defined($_)                } @$data) == 7);
ok((grep { DBI::looks_like_number($_) } @$data) == 7);
ok((grep { $_ >= 0                    } @$data) == 7) or warn "profile data: [@$data]\n";
my ($count, $total, $first, $shortest, $longest, $time1, $time2) = @$data;
if ($shortest < 0) {
    my $sys = "$Config{archname} $Config{osvers}"; # sparc-linux 2.4.20-2.3sparcsmp
    warn "Time went backwards at some point during the test on this $sys system!\n";
    warn "Perhaps you have time sync software (like NTP) that adjusted the clock\n";
    warn "backwards by more than $shortest seconds during the test. PLEASE RETRY.\n";
    # Don't treat very small negative amounts as a failure - it's always been due
    # due to NTP or buggy multiprocessor systems.
    $shortest = 0 if $shortest > -0.008;
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

my $tmp = sanitize_tree($dbh->{Profile});
$tmp->{Data}{$sql}[0] = -1; # make test insensitive to local file count
is_deeply $tmp, bless {
	'Path' => [ DBIprofile_Statement ],
	'Data' => {
		''   => [ 3, 0, 0, 0, 0, 0, 0 ],
		$sql => [ -1, 0, 0, 0, 0, 0, 0 ],
		'set foo=1' => [ 1, 0, 0, 0, 0, 0, 0 ],
	}
} => 'DBI::Profile';

print "Test profile format\n";
my $output = $dbh->{Profile}->format();
print "Profile Output\n$output";

# check that output was produced in the expected format
ok(length $output);
ok($output =~ /^DBI::Profile:/);
ok($output =~ /\((\d+) calls\)/);
ok($1 >= $count);


# try statement and method name path
$dbh = DBI->connect("dbi:ExampleP:", 'usrnam', '', {
    RaiseError => 1,
    Profile => { Path => [ '{Username}', DBIprofile_Statement, 'foo', DBIprofile_MethodName ] }
});
$sql = "select name from .";
$sth = $dbh->prepare($sql);
$sth->execute();
while ( my $hash = $sth->fetchrow_hashref ) {}
undef $sth; # DESTROY

$tmp = sanitize_tree($dbh->{Profile});
# make test insentitive to number of local files
$tmp->{Data}{usrnam}{'select name from .'}{foo}{fetchrow_hashref}[0] = -1;
is_deeply $tmp, bless {
    'Path' => [ '{Username}', DBIprofile_Statement, 'foo', DBIprofile_MethodName ],
    'Data' => {
	'usrnam' => {
	    '' => {
		    'foo' => {
			    'FETCH' => [ 1, 0, 0, 0, 0, 0, 0 ],
			    'STORE' => [ 2, 0, 0, 0, 0, 0, 0 ],
		    },
	    },
	    'select name from .' => {
		    'foo' => {
			'execute' => [ 1, 0, 0, 0, 0, 0, 0 ],
			'fetchrow_hashref' => [ -1, 0, 0, 0, 0, 0, 0 ],
			'DESTROY' => [ 1, 0, 0, 0, 0, 0, 0 ],
			'prepare' => [ 1, 0, 0, 0, 0, 0, 0 ]
		    },
	    },
	},
    },
} => 'DBI::Profile';

print "dbi_profile_merge\n";
my $total_time = dbi_profile_merge(
    my $totals=[],
    [ 10, 0.51, 0.11, 0.01, 0.22, 1023110000, 1023110010 ],
    [ 15, 0.42, 0.12, 0.02, 0.23, 1023110005, 1023110009 ],
);        
$_ = sprintf "%.2f", $_ for @$totals; # avoid precision issues
is("@$totals", "25.00 0.93 0.11 0.01 0.23 1023110000.00 1023110010.00");
is($total_time, 0.93);

$total_time = dbi_profile_merge(
    $totals=[], {
	foo => [ 10, 1.51, 0.11, 0.01, 0.22, 1023110000, 1023110010 ],
        bar => [ 17, 1.42, 0.12, 0.02, 0.23, 1023110005, 1023110009 ],
    }
);        
$_ = sprintf "%.2f", $_ for @$totals; # avoid precision issues
is("@$totals", "27.00 2.93 0.11 0.01 0.23 1023110000.00 1023110010.00");
is($total_time, 2.93);

DBI->trace(0, "STDOUT"); # close current log to flush it
ok(-s $LOG_FILE); # check that output went into the log file

exit 0;


sub sanitize_tree {
    my $data = shift;
    return $data unless ref $data;
    $data = dclone($data);
    my $tree = (exists $data->{Path} && exists $data->{Data}) ? $data->{Data} : $data;
    _sanitize_node($_) for values %$tree;
    return $data;
}

sub _sanitize_node {
    my $node = shift;
    if (ref $node eq 'HASH') {
        _sanitize_node($_) for values %$node;
    }
    elsif (ref $node eq 'ARRAY') {
	# sanitize the profile data node so tests
	$_ = 0 for @{$node}[1..@$node-1]; # not 0
    }
    return;
}
