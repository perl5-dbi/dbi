#!perl

use strict;
use warnings;
use Time::HiRes qw(time);

BEGIN { $ENV{PERL_ANYEVENT_STRICT} = 1; $ENV{PERL_ANYEVENT_VERBOSE} = 1; }

use AnyEvent;

BEGIN { $ENV{DBI_TRACE} = 0; $ENV{DBI_PUREPERL} = 0; $ENV{DBI_GOFER_TRACE} = 0; $ENV{DBD_GOFER_TRACE} = 0; };

use DBI;

$ENV{DBI_AUTOPROXY} = 'dbi:Gofer:transport=corostream';

my $ticker = AnyEvent->timer( after => 0, interval => 0.1, cb => sub {
    warn sprintf "-tick- %.2f\n", time
} );

warn "connecting...\n";
my $dbh = DBI->connect("dbi:NullP:");
warn "...connected\n";

for (1..5) {
    warn "entering DBI...\n";
    $dbh->do("sleep 0.3"); # pseudo-sql understood by the DBD::NullP driver
    warn "...returned\n";
}

warn "done.";

