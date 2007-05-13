#!perl -w
$|=1;

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

use Test::More;

BEGIN {
    plan skip_all => "profiling not supported for DBI::PurePerl"
        if $DBI::PurePerl;
    # tie methods (STORE/FETCH etc) get called different number of times
    plan skip_all => "test results assume perl >= 5.8.2"
        if $] <= 5.008001;
    plan tests => 51;
}

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

my $t_file = __FILE__;
$dbh->do("set foo=1"); my $line = __LINE__;
my $expected_caller = "40profile.t line $line";
$expected_caller .= " via ${1}40profile.t line 3"
    if $0 =~ /(zv\w+_)/;
print Dumper($dbh->{Profile});
is_deeply sanitize_tree($dbh->{Profile}), bless {
	'Path' => [ '!MethodName', '!Caller2' ],
	'Data' => { 'do' => {
	    $expected_caller => [ 1, 0, 0, 0, 0, 0, 0 ]
	} }
} => 'DBI::Profile';
#die Dumper $dbh->{Profile};


# can turn it on at connect
$dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1, Profile=>6 });
is_deeply $dbh->{Profile}{Path}, [ '!Statement', '!MethodName' ];
cmp_ok(keys %{ $dbh->{Profile}{Data} },     '==', 1);
cmp_ok(keys %{ $dbh->{Profile}{Data}{""} }, '>=', 1); # at least STORE
ok(        ref $dbh->{Profile}{Data}{""}{STORE}    );

print "dbi_profile\n";
# Try to avoid rounding problem on double precision systems
#   $got->[5]      = '1150962858.01596498'
#   $expected->[5] = '1150962858.015965'
# by treating as a string (because is_deeply stringifies)
my $t1 = DBI::dbi_time() . ""; 
my $dummy_statement = "Hi mom";
my $dummy_methname  = "my_method_name";
dbi_profile($dbh, $dummy_statement, $dummy_methname, $t1, $t1 + 1);
print Dumper($dbh->{Profile});
cmp_ok(keys %{ $dbh->{Profile}{Data} }, '==', 2);
cmp_ok(keys %{ $dbh->{Profile}{Data}{$dummy_statement} }, '==', 1);
ok(        ref $dbh->{Profile}{Data}{$dummy_statement}{$dummy_methname}    );

my $mine = $dbh->{Profile}{Data}{$dummy_statement}{$dummy_methname};
print "@$mine\n";
is_deeply $mine, [ 1, 1, 1, 1, 1, $t1, $t1 ];

my $t2 = DBI::dbi_time() . "";
dbi_profile($dbh, $dummy_statement, $dummy_methname, $t2, $t2 + 2);
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
my ($count, $total, $first, $shortest, $longest, $time1, $time2) = @$data;
ok($count > 3);
ok($total > $first);
ok($total > $longest) or warn "total $total > longest $longest: failed\n";
ok($longest > 0) or warn "longest $longest > 0: failed\n"; # XXX theoretically not reliable
ok($longest > $shortest);
ok($time1 >= $^T);
ok($time2 >= $^T);
ok($time1 <= $time2);
my $next = time + 1;
ok($next > $time1) or warn "next $next > first $time1: failed\n";
ok($next > $time2) or warn "next $next > last $time2: failed\n";
if ($shortest < 0) {
    my $sys = "$Config{archname} $Config{osvers}"; # ie sparc-linux 2.4.20-2.3sparcsmp
    warn <<EOT;
Time went backwards at some point during the test on this $sys system!
Perhaps you have time sync software (like NTP) that adjusted the clock
by more than $shortest seconds during the test.
Also some multiprocessor systems, and some virtualization systems can exhibit
this kind of clock behaviour. Please retry.
EOT
    # don't treat small negative values as failure
    $shortest = 0 if $shortest > -0.008;
}


my $tmp = sanitize_tree($dbh->{Profile});
$tmp->{Data}{$sql}[0] = -1; # make test insensitive to local file count
is_deeply $tmp, bless {
	'Path' => [ '!Statement' ],
	'Data' => {
		''   => [ 7, 0, 0, 0, 0, 0, 0 ],
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

# try statement and method name and reference-to-scalar path
my $by_reference = 'foo';
$dbh = DBI->connect("dbi:ExampleP:", 'usrnam', '', {
    RaiseError => 1,
    Profile => { Path => [ '{Username}', '!Statement', \$by_reference, '!MethodName' ] }
});
$sql = "select name from .";
$sth = $dbh->prepare($sql);
$sth->execute();
$sth->fetchrow_hashref;
$by_reference = 'bar';
$sth->finish;
undef $sth; # DESTROY

$tmp = sanitize_tree($dbh->{Profile});
ok $tmp->{Data}{usrnam}{""}{foo}{STORE};
$tmp->{Data}{usrnam}{""}{foo} = {};
# make test insentitive to number of local files
#warn Dumper($tmp);
is_deeply $tmp, bless {
    'Path' => [ '{Username}', '!Statement', \$by_reference, '!MethodName' ],
    'Data' => {
        '' => { # because Profile was enabled by DBI just before Username was set
            '' => {
                'foo' => {
                    'STORE' => [ 3, 0, 0, 0, 0, 0, 0 ],
                }
            }
        },
	'usrnam' => {
	    '' => {
		    'foo' => { },
	    },
	    'select name from .' => {
		    'foo' => {
			'execute' => [ 1, 0, 0, 0, 0, 0, 0 ],
			'fetchrow_hashref' => [ 1, 0, 0, 0, 0, 0, 0 ],
			'prepare' => [ 1, 0, 0, 0, 0, 0, 0 ],
		    },
		    'bar' => {
			'DESTROY' => [ 1, 0, 0, 0, 0, 0, 0 ],
			'finish' => [ 1, 0, 0, 0, 0, 0, 0 ],
		    },
	    },
	},
    },
} => 'DBI::Profile';


$dbh->{Profile}->{Path} = [ '!File', '!File2', '!Caller', '!Caller2' ];
$dbh->{Profile}->{Data} = undef;

my $file = (File::Spec->splitpath(__FILE__))[2]; # '40profile.t'
my ($line1, $line2);
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
    $sth->finish;
    undef $sth; # DESTROY
    return sanitize_profile_data_nodes($dbh->{Profile}{Data});
}

$tmp = run_test1( { Path => [ 'foo', sub { 'bar' }, 'baz' ] });
is_deeply $tmp, { 'foo' => { 'bar' => { 'baz' => [ 12, 0,0,0,0,0,0 ] } } };

$tmp = run_test1( { Path => [ 'foo', sub { 'ping','pong' } ] });
is_deeply $tmp, { 'foo' => { 'ping' => { 'pong' => [ 12, 0,0,0,0,0,0 ] } } };

$tmp = run_test1( { Path => [ 'foo', sub { \undef } ] });
is_deeply $tmp, { 'foo' => undef }, 'should be vetoed';

# check what code ref sees in $_
$tmp = run_test1( { Path => [ sub { $_ } ] });
is_deeply $tmp, {
  '' => [ 7, 0, 0, 0, 0, 0, 0 ],
  'select name from .' => [ 5, 0, 0, 0, 0, 0, 0 ]
}, '$_ should contain statement';

# check what code ref sees in @_
$tmp = run_test1( { Path => [ sub { my ($h,$method) = @_; return \undef if $method =~ /^[A-Z]+$/; return (ref $h, $method) } ] });
is_deeply $tmp, {
  'DBI::db' => {
    'connected' => [ 1, 0, 0, 0, 0, 0, 0 ],
    'prepare' => [ 1, 0, 0, 0, 0, 0, 0 ],
  },
  'DBI::st' => {
    'fetchrow_hashref' => [ 1, 0, 0, 0, 0, 0, 0 ],
    'execute' => [ 1, 0, 0, 0, 0, 0, 0 ],
    'finish'  => [ 1, 0, 0, 0, 0, 0, 0 ],
  },
}, 'should have @_ as keys';

# check we can filter by method
$tmp = run_test1( { Path => [ sub { return \undef unless $_[1] =~ /^fetch/; return $_[1] } ] });
#warn Dumper($tmp);
is_deeply $tmp, {
    'fetchrow_hashref' => [ 1, 0, 0, 0, 0, 0, 0 ],
}, 'should be able to filter by method';

DBI->trace(0, "STDOUT"); # close current log to flush it
ok(-s $LOG_FILE, 'output should go to log file');

# -----------------------------------------------------------------------------------

print "dbi_profile_merge_nodes\n";
my $total_time = dbi_profile_merge_nodes(
    my $totals=[],
    [ 10, 0.51, 0.11, 0.01, 0.22, 1023110000, 1023110010 ],
    [ 15, 0.42, 0.12, 0.02, 0.23, 1023110005, 1023110009 ],
);        
$_ = sprintf "%.2f", $_ for @$totals; # avoid precision issues
is("@$totals", "25.00 0.93 0.11 0.01 0.23 1023110000.00 1023110010.00");
is($total_time, 0.93);

$total_time = dbi_profile_merge_nodes(
    $totals=[], {
	foo => [ 10, 1.51, 0.11, 0.01, 0.22, 1023110000, 1023110010 ],
        bar => [ 17, 1.42, 0.12, 0.02, 0.23, 1023110005, 1023110009 ],
    }
);        
$_ = sprintf "%.2f", $_ for @$totals; # avoid precision issues
is("@$totals", "27.00 2.93 0.11 0.01 0.23 1023110000.00 1023110010.00");
is($total_time, 2.93);

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
