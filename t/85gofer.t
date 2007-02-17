#!perl -w                                         # -*- perl -*-
# vim:sw=4:ts=8
$|=1;

use strict;
use warnings;

use Time::HiRes qw(time);
use Data::Dumper;
use Test::More 'no_plan';

use DBI;

# 0=SQL::Statement if avail, 1=DBI::SQL::Nano
# next line forces use of Nano rather than default behaviour
$ENV{DBI_SQL_NANO}=1;

my $perf_count = (@ARGV && $ARGV[0] =~ s/^-c=//) ? shift : (-t STDOUT) ? 100 : 0;
my %durations;

# so users can try others from the command line
my $dbm = $ARGV[0] || "SDBM_File";
my $remote_driver_dsn = "dbm_type=$dbm;lockfile=0";
my $remote_dsn = "dbi:DBM:$remote_driver_dsn";

if ($ENV{DBI_AUTOPROXY}) {
    # this means we have DBD::Gofer => DBD::Gofer => DBD::DBM!
    # rather than disable it we let it run because we're twisted
    # and because it helps find more bugs (though debugging can be painful)
    warn "\n$0 is running with DBI_AUTOPROXY enabled ($ENV{DBI_AUTOPROXY})\n"
        unless $0 =~ /\bzv/; # don't warn for t/zvg_85gofer.t
}

my $username = getpwuid($>);
my %transports = (
    null => {},
    pipeone => {},
#   stream => { url => "ssh:$username\@localhost" },
    http => { url => "http://localhost:8001/gofer" },
);
# delete stream test for everyone else because it's to dependent
# on local configuration issues unrelated to the DBI
delete $transports{stream} unless $username eq 'timbo' && -d '.svn';
delete $transports{http} unless $username eq 'timbo' && -d '.svn';

for my $transport (keys %transports) {
    my $trans_attr = $transports{$transport};

    for my $policy_name (qw(pedantic classic rush)) {

        eval { run_tests($transport, $trans_attr, $policy_name) };
        ($@) ? fail($@) : pass();

    }
}

# to get baseline for comparisons if doing performance testing
run_tests('no', {}, 'pedantic') if $perf_count;

while ( my ($activity, $stats_hash) = each %durations ) {
    print "\n";
    $stats_hash->{'~baseline~'} = delete $stats_hash->{"no+pedantic"};
    for my $perf_tag (reverse sort keys %$stats_hash) {
        my $dur = $stats_hash->{$perf_tag};
        printf "  %6s %-13s: %.6fsec (%5d/sec)",
            $activity, $perf_tag, $dur/$perf_count, $perf_count/$dur;
        my $baseline_dur = $stats_hash->{'~baseline~'};
        printf " %+5.1fms", (($dur-$baseline_dur)/$perf_count)*1000
            unless $perf_tag eq '~baseline~';
        print "\n";
    }
}


sub run_tests {
    my ($transport, $trans_attr, $policy_name) = @_;

    my $policy = get_policy($policy_name);

    my $test_run_tag = "Testing $transport transport with $policy_name policy";
    print "\n$test_run_tag\n";

    my $driver_dsn = "transport=$transport;policy=$policy_name";
    $driver_dsn .= join ";", '', map { "$_=$trans_attr->{$_}" } keys %$trans_attr
        if %$trans_attr;

    my $dsn = "dbi:Gofer:$driver_dsn;dsn=$remote_dsn";
    $dsn = $remote_dsn if $transport eq 'no';
    print " $dsn\n";

    my $dbh = DBI->connect($dsn, undef, undef, { HandleError => sub { print $_[0]; 1 } } );
    ok $dbh, 'should connect';
    die "$test_run_tag aborted\n" unless $dbh;

    is $dbh->{Name}, ($policy->skip_connect_check or $policy->dbh_attribute_update eq 'none')
        ? $driver_dsn
        : $remote_driver_dsn;

    ok $dbh->do("DROP TABLE IF EXISTS fruit");
    ok $dbh->do("CREATE TABLE fruit (dKey INT, dVal VARCHAR(10))");
    die "$test_run_tag aborted\n" if $DBI::err;

    my $sth;
    $sth = $dbh->prepare("complete non-sql gibberish");
    ($policy->skip_prepare_check)
        ? isa_ok $sth, 'DBI::st'
        : is $sth, undef, 'should detect prepare failure';

    ok my $ins_sth = $dbh->prepare("INSERT INTO fruit VALUES (?,?)");
    ok $ins_sth->execute(1, 'oranges');
    ok $ins_sth->execute(2, 'oranges');

    my $rowset;
    ok $rowset = $dbh->selectall_arrayref("SELECT dKey, dVal FROM fruit");
    is_deeply($rowset, [ [ '1', 'oranges' ], [ '2', 'oranges' ] ]);

    ok $dbh->do("UPDATE fruit SET dVal='apples' WHERE dVal='oranges'");

    ok $sth = $dbh->prepare("SELECT dKey, dVal FROM fruit");
    ok $sth->execute;
    ok $rowset = $sth->fetchall_hashref('dKey');
    is_deeply($rowset, { '1' => { dKey=>1, dVal=>'apples' }, 2 => { dKey=>2, dVal=>'apples' } });

    if ($perf_count and $transport ne 'pipeone') {
        my $start = time();
        $dbh->selectall_arrayref("SELECT dKey, dVal FROM fruit")
            for (1000..1000+$perf_count);
        $durations{select}{"$transport+$policy_name"} = time() - $start;

        # some rows in to get a (*very* rough) idea of overheads
        $start = time();
        $ins_sth->execute($_, 'speed')
            for (1000..1000+$perf_count);
        $durations{insert}{"$transport+$policy_name"} = time() - $start;
    }

    ok $dbh->do("DROP TABLE fruit");
    ok $dbh->disconnect;
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
