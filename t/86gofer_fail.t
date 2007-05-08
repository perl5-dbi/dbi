#!perl -w                                         # -*- perl -*-
# vim:sw=4:ts=8
$|=1;

use strict;
use warnings;

use DBI;
use Data::Dumper;
use Test::More;
sub between_ok;

# here we test the DBI_GOFER_RANDOM mechanism
# and how gofer deals with failures

plan skip_all => "requires Callbacks which are not supported with PurePerl" if $DBI::PurePerl;

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

# silence the "DBI_GOFER_RANDOM..." warnings
my @warns;
$SIG{__WARN__} = sub { ("@_" =~ /^DBI_GOFER_RANDOM/) ? push(@warns, @_) : warn @_; };

# --- 100% failure rate

$ENV{DBI_GOFER_RANDOM} = "fail=100%,do"; # total failure
my $dbh_100 = DBI->connect("dbi:Gofer:transport=null;policy=rush;dsn=dbi:ExampleP:", 0, 0, {
    RaiseError => 1, PrintError => 0,
});
ok $dbh_100;

ok !eval { $dbh_100->do("set foo=1") }, 'do method should fail';
ok $dbh_100->errstr, 'errstr should be set';
ok $@, '$@ should be set';
like $@, '/fake error induced by DBI_GOFER_RANDOM/';
like $dbh_100->errstr, '/DBI_GOFER_RANDOM/', 'errstr should contain DBI_GOFER_RANDOM';

ok !$dbh_100->{go_response}->executed_flag_set, 'go_response executed flag should be false';

is precentage_exceptions(200, sub { $dbh_100->do("set foo=1") }), 100;

# XXX randomness can't be predicted, so it's just possible these will fail

# --- 50% failure rate, with no retries

$ENV{DBI_GOFER_RANDOM} = "fail=50%,do"; # 50% failure (almost)
ok my $dbh_50r0 = dbi_connect("policy=rush;retry_limit=0");
$fails = precentage_exceptions(200, sub { $dbh_50r0->do("set foo=1") });
print "target approx 50% random failures, got $fails%\n";
between_ok $fails, 10, 90, "should fail about 50% of the time, but at least between 10% and 90%";

# --- 50% failure rate, with many retries (should yield low failure rate)

$ENV{DBI_GOFER_RANDOM} = "fail=50%,prepare"; # 50% failure (almost)
ok my $dbh_50r5 = dbi_connect("policy=rush;retry_limit=5");
$fails = precentage_exceptions(200, sub { $dbh_50r5->prepare("set foo=1") });
print "target approx 5% random failures, got $fails%\n";
cmp_ok $fails, '<', 20, 'should fail < 20%';

# --- 10% failure rate, with many retries (should yield zero failure rate)

$ENV{DBI_GOFER_RANDOM} = "fail=10,do"; # without the % this time
ok my $dbh_1r10 = dbi_connect("policy=rush;retry_limit=10");
$fails = precentage_exceptions(200, sub { $dbh_1r10->do("set foo=1") });
cmp_ok $fails, '<', 1, 'should fail < 1%';

# --- 50% failure rate, test is_idempotent

$ENV{DBI_GOFER_RANDOM} = "fail=50%,do";   # 50%

# test go_retry_hook and that ReadOnly => 1 retries a non-idempotent statement
ok my $dbh_50r1ro = dbi_connect("policy=rush;retry_limit=1", {
    go_retry_hook => sub { return ($_[0]->is_idempotent) ? 1 : 0 },
    ReadOnly => 1,
} );
between_ok precentage_exceptions(100, sub { $dbh_50r1ro->do("set foo=1") }),
    15, 35, 'should fail ~25% (ie 50% with one retry)';
between_ok $dbh_50r1ro->{go_transport}->meta->{request_retry_count},
    35, 65, 'transport request_retry_count should be around 50';

# test as above but with ReadOnly => 0
ok my $dbh_50r1rw = dbi_connect("policy=rush;retry_limit=1", {
    go_retry_hook => sub { return ($_[0]->is_idempotent) ? 1 : 0 },
    ReadOnly => 0,
} );
between_ok precentage_exceptions(100, sub { $dbh_50r1rw->do("set foo=1") }),
    35, 65, 'should fail ~50%, ie no retries';
ok !$dbh_50r1rw->{go_transport}->meta->{request_retry_count},
    'transport request_retry_count should be zero or undef';


# ---
print "Testing random delay\n";

$ENV{DBI_GOFER_RANDOM} = "delay0.1=51%,do"; # odd percentage to force warn()s
@warns = ();
ok my $dbh = dbi_connect("policy=rush;retry_limit=0");
is precentage_exceptions(10, sub { $dbh->do("set foo=1") }),
    0, "should not fail for DBI_GOFER_RANDOM='$ENV{DBI_GOFER_RANDOM}'";
my $delays = grep { m/delaying execution/ } @warns;
between_ok $delays, 2, 9, 'should be delayed around 5 times';

exit 0;

sub between_ok {
    my ($got, $min, $max, $label) = @_;
    local $Test::Builder::Level = 2;
    cmp_ok $got, '>=', $min, "$label (got $got)";
    cmp_ok $got, '<=', $max, "$label (got $got)";
}

sub dbi_connect {
    my ($gdsn, $attr) = @_;
    return DBI->connect("dbi:Gofer:transport=null;$gdsn;dsn=dbi:ExampleP:", 0, 0, {
        RaiseError => 1, PrintError => 0, ($attr) ? %$attr : ()
    });
}

sub precentage_exceptions {
    my ($count, $sub) = @_;
    my $i = $count;
    my $exceptions = 0;
    while ($i--) {
        eval { $sub->() };
        if ($@) {
            die "Unexpected failure: $@" unless $@ =~ /DBI_GOFER_RANDOM/;
            ++$exceptions;
        }
    }
    return $exceptions/$count*100;
}
