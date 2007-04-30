#!perl -w                                         # -*- perl -*-
# vim:sw=4:ts=8
$|=1;

use strict;
use warnings;

use DBI;
use Data::Dumper;
use Test::More;

# here we test the DBI_GOFER_RANDOM_FAIL mechanism
# and how gofer deals with failures

plan skip_all => "DBI_GOFER_RANDOM_FAIL not supported with PurePerl" if $DBI::PurePerl;

if (my $ap = $ENV{DBI_AUTOPROXY}) { # limit the insanity
    plan skip_all => "Gofer DBI_AUTOPROXY" if $ap =~ /^dbi:Gofer/i;

    # this means we have DBD::Gofer => DBD::Gofer => DBD::whatever
    # rather than disable it we let it run because we're twisted
    # and because it helps find more bugs (though debugging can be painful)
    warn "\n$0 is running with DBI_AUTOPROXY enabled ($ENV{DBI_AUTOPROXY})\n"
        unless $0 =~ /\bzv/; # don't warn for t/zvg_85gofer.t
}

plan 'no_plan';

my $tmp;
my $fails;

# we'll use the null transport for simplicity and speed
# and the rush policy to limit the number of interactions with the gofer executor

# silence the "DBI_GOFER_RANDOM_FAIL set ..." warning
$SIG{__WARN__} = sub { warn "@_" unless "@_" =~ /^DBI_GOFER_RANDOM_FAIL set/ };

# --- 100% failure rate

$ENV{DBI_GOFER_RANDOM_FAIL} = "1,do"; # total failure (almost)
my $dbh_100 = DBI->connect("dbi:Gofer:transport=null;policy=rush;dsn=dbi:ExampleP:", 0, 0, {
    RaiseError => 1, PrintError => 0,
});
ok $dbh_100;

ok !eval { $dbh_100->do("set foo=1") }, 'do method should fail';
ok $dbh_100->errstr, 'errstr should be set';
ok $@, '$@ should be set';
like $@, '/fake error induced by DBI_GOFER_RANDOM_FAIL/';
like $dbh_100->errstr, '/DBI_GOFER_RANDOM_FAIL/', 'errstr should contain DBI_GOFER_RANDOM_FAIL';

ok !$dbh_100->{go_response}->executed_flag_set, 'go_response executed flag should be false';

is precentage_exceptions(200, sub { $dbh_100->do("set foo=1") }), 100;

# XXX randomness can't be predicted, so it's just possible these will fail

# --- 50% failure rate, with no retries

$ENV{DBI_GOFER_RANDOM_FAIL} = "2,do"; # 50% failure (almost)
ok my $dbh_50r0 = dbi_connect("policy=rush;retry_limit=0");
$fails = precentage_exceptions(200, sub { $dbh_50r0->do("set foo=1") });
print "target approx 50% random failures, got $fails%\n";
cmp_ok $fails, '>', 10, 'should fail about 50% of the time, but at least 10%';
cmp_ok $fails, '<', 90, 'should fail about 50% of the time, but not more than 90%';

# --- 50% failure rate, with many retries (should yield low failure rate)

$ENV{DBI_GOFER_RANDOM_FAIL} = "2,do"; # 50% failure (almost)
ok my $dbh_50r5 = dbi_connect("policy=rush;retry_limit=5");
$fails = precentage_exceptions(200, sub { $dbh_50r5->do("set foo=1") });
print "target approx 5% random failures, got $fails%\n";
cmp_ok $fails, '<', 20, 'should fail < 20%';

# --- 10% failure rate, with many retries (should yield zero failure rate)

$ENV{DBI_GOFER_RANDOM_FAIL} = "10,do";
ok my $dbh_1r10 = dbi_connect("policy=rush;retry_limit=10");
$fails = precentage_exceptions(200, sub { $dbh_1r10->do("set foo=1") });
cmp_ok $fails, '<', 1, 'should fail < 1%';


exit 0;

sub dbi_connect {
    my ($gdsn) = @_;
    return DBI->connect("dbi:Gofer:transport=null;$gdsn;dsn=dbi:ExampleP:", 0, 0, {
        RaiseError => 1, PrintError => 0,
    });
}

sub precentage_exceptions {
    my ($count, $sub) = @_;
    my $i = $count;
    my $exceptions = 0;
    while ($i--) {
        eval { $sub->() };
        if ($@) {
            die "Unexpected failure: $@" unless $@ =~ /DBI_GOFER_RANDOM_FAIL/;
            ++$exceptions;
        }
    }
    return $exceptions/$count*100;
}
