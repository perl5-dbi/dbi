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

use Test::More tests => 46;

$Data::Dumper::Indent = 1;
$Data::Dumper::Terse = 1;

# log file to store profile results 
my $LOG_FILE = "profile.log";
my $orig_dbi_debug = $DBI::dbi_debug;
DBI->trace($DBI::dbi_debug, $LOG_FILE);
END {
    return if $orig_dbi_debug;
    1 while unlink $LOG_FILE;
}


print "Test enabling the profile\n";

# make sure profiling starts disabled
my $dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1 });
ok($dbh);
ok(!$dbh->{Profile} && !$ENV{DBI_PROFILE});


# can turn it on after the fact using a path number
$dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1 });
$dbh->{Profile} = "4";
is_deeply sanitize_tree($dbh->{Profile}), bless {
	'Path' => [ '!MethodName' ],
} => 'DBI::Profile';

# using a package name
$dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1 });
$dbh->{Profile} = "/DBI::Profile";
is_deeply sanitize_tree($dbh->{Profile}), bless {
	'Path' => [ ],
} => 'DBI::Profile';

# using a combined path and name
$dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1 });
$dbh->{Profile} = "20/DBI::Profile";
is_deeply sanitize_tree($dbh->{Profile}), bless {
	'Path' => [ '!MethodName', '!Caller2' ],
} => 'DBI::Profile';

$dbh->do("set foo=1"); my $line = __LINE__;
is_deeply sanitize_tree($dbh->{Profile}), bless {
	'Path' => [ '!MethodName', '!Caller2' ],
	'Data' => { 'do' => {
		"40profile.t line $line" => [ 1, 0, 0, 0, 0, 0, 0 ]
	} }
} => 'DBI::Profile';
#die Dumper $dbh->{Profile};


# can turn it on at connect
$dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1, Profile=>6 });
is_deeply sanitize_tree($dbh->{Profile}), bless {
	'Path' => [ '!Statement', '!MethodName' ],
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
	'Path' => [ '!Statement', '!MethodName' ],
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
	'Path' => [ '!Statement' ],
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

# -----------------------------------------------------------------------------------

# try statement and method name path
$dbh = DBI->connect("dbi:ExampleP:", 'usrnam', '', {
    RaiseError => 1,
    Profile => { Path => [ '{Username}', '!Statement', 'foo', '!MethodName' ] }
});
$sql = "select name from .";
$sth = $dbh->prepare($sql);
$sth->execute();
$sth->fetchrow_hashref;
undef $sth; # DESTROY

$tmp = sanitize_tree($dbh->{Profile});
# make test insentitive to number of local files
is_deeply $tmp, bless {
    'Path' => [ '{Username}', '!Statement', 'foo', '!MethodName' ],
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
			'fetchrow_hashref' => [ 1, 0, 0, 0, 0, 0, 0 ],
			'DESTROY' => [ 1, 0, 0, 0, 0, 0, 0 ],
			'prepare' => [ 1, 0, 0, 0, 0, 0, 0 ],
                        # XXX finish shouldn't be profiled as it's not called explicitly
                        # but currently the finish triggered by DESTROY does get profiled
			'finish' => [ 1, 0, 0, 0, 0, 0, 0 ],
		    },
	    },
	},
    },
} => 'DBI::Profile';


$dbh->{Profile}->{Path} = [ '!File', '!File2', '!Caller', '!Caller2' ];
$dbh->{Profile}->{Data} = undef;

my ($file, $line1, $line2) = (__FILE__, undef, undef);
$file =~ s:.*/::;
sub a_sub {
    $sth = $dbh->prepare("select name from ."); $line2 = __LINE__;
}
a_sub(); $line1 = __LINE__;

$tmp = sanitize_profile_data_nodes($dbh->{Profile}{Data});
#warn Dumper($tmp);
is_deeply $tmp, {
  "$file" => {
    "$file via $file" => {
      "$file line $line2" => {
        "$file line $line2 via $file line $line1" => [ 1, 0, 0, 0, 0, 0, 0 ]
      }
    }
  }
};


$dbh->{Profile} = '&norm_std_n3'; # assign as string to get magic
is_deeply $dbh->{Profile}{Path}, [
    \&DBI::ProfileSubs::norm_std_n3
];
$dbh->{Profile}->{Data} = undef;
$sql = qq{insert into foo20060726 (a,b) values (42,"foo")};
dbi_profile($dbh, $sql, 'mymethod', 100000000, 100000002);
$tmp = $dbh->{Profile}{Data};
#warn Dumper($tmp);
is_deeply $tmp, {
    'insert into foo<N> (a,b) values (<N>,"<S>")' => [ 1, '2', '2', '2', '2', '100000000', '100000000' ]
};


# -----------------------------------------------------------------------------------

print "testing code ref in Path\n";

sub run_test1 {
    my ($profile) = @_;
    $dbh = DBI->connect("dbi:ExampleP:", 'usrnam', '', {
        RaiseError => 1,
        Profile => $profile,
    });
    $sql = "select name from .";
    $sth = $dbh->prepare($sql);
    $sth->execute();
    $sth->fetchrow_hashref;
    undef $sth; # DESTROY
    return sanitize_profile_data_nodes($dbh->{Profile}{Data});
}

$tmp = run_test1( { Path => [ 'foo', sub { 'bar' }, 'baz' ] });
is_deeply $tmp, { 'foo' => { 'bar' => { 'baz' => [ 8, 0,0,0,0,0,0 ] } } };

$tmp = run_test1( { Path => [ 'foo', sub { 'ping','pong' } ] });
is_deeply $tmp, { 'foo' => { 'ping' => { 'pong' => [ 8, 0,0,0,0,0,0 ] } } };

$tmp = run_test1( { Path => [ 'foo', sub { \undef } ] });
is_deeply $tmp, { 'foo' => undef }, 'should be vetoed';

# check what code ref sees in $_
$tmp = run_test1( { Path => [ sub { $_ } ] });
is_deeply $tmp, {
  '' => [ 3, 0, 0, 0, 0, 0, 0 ],
  'select name from .' => [ 5, 0, 0, 0, 0, 0, 0 ]
}, '$_ should contain statement';

# check what code ref sees in @_
$tmp = run_test1( { Path => [ sub { my ($h,$method) = @_; return (ref $h, $method) } ] });
is_deeply $tmp, {
  'DBI::db' => {
    'FETCH'   => [ 1, 0, 0, 0, 0, 0, 0 ],
    'prepare' => [ 1, 0, 0, 0, 0, 0, 0 ],
    'STORE'   => [ 2, 0, 0, 0, 0, 0, 0 ],
  },
  'DBI::st' => {
    'fetchrow_hashref' => [ 1, 0, 0, 0, 0, 0, 0 ],
    'execute' => [ 1, 0, 0, 0, 0, 0, 0 ],
    'finish'  => [ 1, 0, 0, 0, 0, 0, 0 ],
    'DESTROY' => [ 1, 0, 0, 0, 0, 0, 0 ],
  },
}, 'should have @_ as keys';

# check we can filter by method
$tmp = run_test1( { Path => [ sub { return \undef unless $_[1] =~ /^fetch/; return $_[1] } ] });
#warn Dumper($tmp);
is_deeply $tmp, {
    'fetchrow_hashref' => [ 1, 0, 0, 0, 0, 0, 0 ],
}, 'should be able to filter by method';

# -----------------------------------------------------------------------------------

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
    sanitize_profile_data_nodes($data->{Data}) if $data->{Data};
    return $data;
}

sub sanitize_profile_data_nodes {
    my $node = shift;
    if (ref $node eq 'HASH') {
        sanitize_profile_data_nodes($_) for values %$node;
    }
    elsif (ref $node eq 'ARRAY') {
        if (@$node == 7 and DBI::looks_like_number($node->[0])) {
            # sanitize the profile data node to simplify tests
            $_ = 0 for @{$node}[1..@$node-1]; # not 0
        }
    }
    return $node;
}
