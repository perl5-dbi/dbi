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

if (my $ap = $ENV{DBI_AUTOPROXY}) { # limit the insanity
    plan skip_all => "non-gofer DBI_AUTOPROXY" if $ap !~ /^dbi:Gofer/i;

    # this means we have DBD::Gofer => DBD::Gofer => DBD::whatever
    # rather than disable it we let it run because we're twisted
    # and because it helps find more bugs (though debugging can be painful)
    warn "\n$0 is running with DBI_AUTOPROXY enabled ($ENV{DBI_AUTOPROXY})\n"
        unless $0 =~ /\bzv/; # don't warn for t/zvg_85gofer.t
}

plan 'no_plan';

# we'll use the null transport for simplicity and speed
# and the rush policy to limit the number of interactions with the gofer executor

# silence the "DBI_GOFER_RANDOM_FAIL set ..." warning
$SIG{__WARN__} = sub { warn "@_" unless "@_" =~ /^DBI_GOFER_RANDOM_FAIL set/ };

$ENV{DBI_GOFER_RANDOM_FAIL} = "1,do"; # total failure (almost)
my $dbh_100 = DBI->connect("dbi:Gofer:transport=null;policy=rush;dsn=dbi:ExampleP:", 0, 0, {
    RaiseError => 1, PrintError => 0,
});
ok $dbh_100;

sub precentage_exceptions {
    my ($count, $sub) = @_;
    my $i = $count;
    my $exceptions;
    while ($i--) {
        eval { $sub->() };
        if ($@) {
            die "Unexpected failure: $@" unless $@ =~ /DBI_GOFER_RANDOM_FAIL/;
            ++$exceptions;
        }
    }
    return $exceptions/$count*100;
}

is precentage_exceptions(200, sub { $dbh_100->do("set foo=1") }), 100;


$ENV{DBI_GOFER_RANDOM_FAIL} = "2,do"; # 50% failure (almost)
my $dbh_50 = DBI->connect("dbi:Gofer:transport=null;policy=rush;dsn=dbi:ExampleP:", 0, 0, {
    RaiseError => 1, PrintError => 0,
});
ok $dbh_50;
my $fails = precentage_exceptions(200, sub { $dbh_50->do("set foo=1") });
print "target approx 50% random failures, got $fails%\n";
# XXX randomness can't be predicted, so it's just possible these will fail
cmp_ok $fails, '>', 10, 'should fail about 50% of the time, but at least 10%';
cmp_ok $fails, '<', 90, 'should fail about 50% of the time, but not more than 90%';

undef $@;
1;
