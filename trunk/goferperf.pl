#!perl -w
# vim:sw=4:ts=8
$|=1;

use strict;
use warnings;

use Cwd;
use Time::HiRes qw(time);
use Data::Dumper;
use Getopt::Long;

use DBI;

GetOptions(
    'c|count=i' => \(my $opt_count = 100),
    'dsn=s'     => \(my $opt_dsn),
    'timeout=i' => \(my $opt_timeout = 10),
    'p|policy=s' => \(my $opt_policy = "pedantic,classic,rush"),
) or exit 1;

if ($ENV{DBI_AUTOPROXY}) {
    # this means we have DBD::Gofer => DBD::Gofer => DBD::DBM!
    # rather than disable it we let it run because we're twisted
    # and because it helps find more bugs (though debugging can be painful)
    warn "\n$0 is running with DBI_AUTOPROXY enabled ($ENV{DBI_AUTOPROXY})\n";
}

# ensure subprocess (for pipeone and stream transport) will use the same modules as us, ie ./blib
local $ENV{PERL5LIB} = join ":", @INC;

my %durations;
my $username = eval { getpwuid($>) } || ''; # fails on windows
my $can_ssh = ($username && $username eq 'timbo' && -d '.svn');
my $perl = "$^X"; # ensure sameperl and our blib (note two spaces)
   # ensure blib (note two spaces)
   $perl .= sprintf "  -Mblib=%s/blib", getcwd() if $ENV{PERL5LIB} =~ m{/blib/};

my %trials = (
    null       => {},
    null_ha    => { DBI => "DBIx::HA" },
    pipeone    => { perl=>$perl, timeout=>$opt_timeout },
    stream     => { perl=>$perl, timeout=>$opt_timeout },
    stream_ssh => ($can_ssh)
                ? { perl=>$perl, timeout=>$opt_timeout, url => "ssh:$username\@localhost" }
                : undef,
    http       => { url => "http://localhost:8001/gofer" },
);

# to get baseline for comparisons
run_tests('no', {}, 'no');

for my $trial (@ARGV) {
    (my $transport = $trial) =~ s/_.*//;
    my $trans_attr = $trials{$trial} or do {
        warn "No trial '$trial' defined - skipped";
        next;
    };

    for my $policy_name (split /\s*,\s*/, $opt_policy) {
        eval { run_tests($transport, $trans_attr, $policy_name) };
        warn $@ if $@;
    }
}

while ( my ($activity, $stats_hash) = each %durations ) {
    print "\n";
    $stats_hash->{'~baseline~'} = delete $stats_hash->{"no+no"};
    for my $perf_tag (reverse sort keys %$stats_hash) {
        my $dur = $stats_hash->{$perf_tag};
        printf "  %6s %-16s: %.6fsec (%5d/sec)",
            $activity, $perf_tag, $dur/$opt_count, $opt_count/$dur;
        my $baseline_dur = $stats_hash->{'~baseline~'};
        printf " %+6.2fms", (($dur-$baseline_dur)/$opt_count)*1000
            unless $perf_tag eq '~baseline~';
        print "\n";
    }
}


sub run_tests {
    my ($transport, $trans_attr, $policy_name) = @_;

    my $connect_attr = delete $trans_attr->{connect_attr} || {};
    my $DBI = delete $trans_attr->{DBI} || "DBI";
    _load_class($DBI) if $DBI ne "DBI";

    my $test_run_tag = "Testing $transport transport with $policy_name policy @{[ %$connect_attr ]}";
    print "\n$test_run_tag\n";

    my $dsn = $opt_dsn || $trans_attr->{dsn} || "dbi:NullP:";
    if ($policy_name ne 'no') {
        my $driver_dsn = "transport=$transport;policy=$policy_name";
        $driver_dsn .= join ";", '', map { "$_=$trans_attr->{$_}" } keys %$trans_attr
            if %$trans_attr;
        $dsn = "dbi:Gofer:$driver_dsn;dsn=$dsn";
    }
    print " $dsn\n";

    my $dbh = $DBI->connect($dsn, undef, undef, { %$connect_attr, RaiseError => 1 } );

    $dbh->do("DROP TABLE IF EXISTS fruit");
    $dbh->do("CREATE TABLE fruit (dKey INT, dVal VARCHAR(10))");
    my $ins_sth = $dbh->prepare("INSERT INTO fruit VALUES (?,?)");
    $ins_sth->execute(1, 'apples');
    $ins_sth->execute(2, 'oranges');
    $ins_sth->execute(3, 'lemons');
    $ins_sth->execute(4, 'limes');

    my $start = time();
    $dbh->selectall_arrayref("SELECT dKey, dVal FROM fruit")
        for (1000..1000+$opt_count);
    $durations{select}{"$transport+$policy_name"} = time() - $start;

    # insert some rows in to get a (*very* rough) idea of overheads
    $start = time();
    $ins_sth->execute($_, 'speed')
        for (1000..1000+$opt_count);
    $durations{insert}{"$transport+$policy_name"} = time() - $start;

    $dbh->do("DROP TABLE fruit");
    $dbh->disconnect;
}

sub get_policy {
    my ($policy_class) = @_;
    $policy_class = "DBD::Gofer::Policy::$policy_class" unless $policy_class =~ /::/;
    _load_class($policy_class) or die $@;
    return $policy_class->new();
}

sub _load_class { # return true or false+$@
    my $class = shift;
    (my $pm = $class) =~ s{::}{/}g;
    $pm .= ".pm"; 
    return 1 if eval { require $pm };
    delete $INC{$pm}; # shouldn't be needed (perl bug?) and assigning undef isn't enough
    undef; # error in $@
}   


1;
