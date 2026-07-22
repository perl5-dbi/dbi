#!perl -w
#
# check that the inner-method lookup cache works
# (or rather, check that it doesn't cache things when it shouldn't)

my $use_threads_err;
BEGIN { eval "use threads;"; $use_threads_err = $@; }	# Must be first
use Config qw(%Config);
my $has_threads = $Config{useithreads};
die $use_threads_err if $has_threads && $use_threads_err;

use Test::More;

use strict;

$|=1;
$^W=1;

plan tests => ($has_threads ? 49 : 13);

use_ok( 'DBI' );

sub new_handle {
    my $dbh = DBI->connect("dbi:Sponge:foo","","", {
	PrintError => 0,
	RaiseError => 1,
    });

    my $sth = $dbh->prepare("foo",
	# data for DBD::Sponge to return via fetch
	{ rows =>
	    [
		[ "row0" ],
		[ "row1" ],
		[ "row2" ],
		[ "row3" ],
		[ "row4" ],
		[ "row5" ],
		[ "row6" ],
	    ],
	}
    );

    return ($dbh, $sth);
}


sub Foo::local1 { [ "local1" ] };
sub Foo::local2 { [ "local2" ] };


my $fetch_hook;
{
    package Bar;
    our @ISA = qw(DBD::_::st);
    sub fetch { &$fetch_hook };
}

sub run_tests {
    my ($desc, $dbh, $sth) = @_;
    my $row = $sth->fetch;
    is($row->[0], "row0", "$desc row0");

    {
	# replace CV slot
	no warnings 'redefine';
	local *DBD::Sponge::st::fetch = sub { [ "local0" ] };
	$row = $sth->fetch;
	is($row->[0], "local0", "$desc local0");
    }
    $row = $sth->fetch;
    is($row->[0], "row1", "$desc row1");

    {
	# replace GP
	local *DBD::Sponge::st::fetch = *Foo::local1;
	$row = $sth->fetch;
	is($row->[0], "local1", "$desc local1");
    }
    $row = $sth->fetch;
    is($row->[0], "row2", "$desc row2");

    {
	# replace GV
	local $DBD::Sponge::st::{fetch} = *Foo::local2;
	$row = $sth->fetch;
	is($row->[0], "local2", "$desc local2");
    }
    $row = $sth->fetch;
    is($row->[0], "row3", "$desc row3");

    {
	# @ISA = NoSuchPackage
	local $DBD::Sponge::st::{fetch};
	local @DBD::Sponge::st::ISA = qw(NoSuchPackage);
	eval { local $SIG{__WARN__} = sub {}; $row = $sth->fetch };
	like($@, qr/Can't locate DBI object method/, "$desc locate DBI object");
    }
    $row = $sth->fetch;
    is($row->[0], "row4", "$desc row4");

    {
	# @ISA = Bar
	$fetch_hook = \&DBD::Sponge::st::fetch;
	local $DBD::Sponge::st::{fetch};
	local @DBD::Sponge::st::ISA = qw(Bar);
	$row = $sth->fetch;
	is($row->[0], "row5", "$desc row5");
	$fetch_hook = sub { [ "local3" ] };
	$row = $sth->fetch;
	is($row->[0], "local3", "$desc local3");
    }
    $row = $sth->fetch;
    is($row->[0], "row6", "$desc row6");
}

run_tests("plain", new_handle());


if ($has_threads) {
    # only enable this when handles are allowed to be shared across threads
    #{
    #    my @h = new_handle();
    #    threads->new(sub { run_tests("threads", @h) })->join; 
    #}
    threads->new(sub { run_tests("threads-h", new_handle()) })->join; 

    # using weaken attaches magic to the CV; see whether this interferes
    # with the cache magic

    use Scalar::Util qw(weaken);
    my $fetch_ref = \&DBI::st::fetch;
    weaken $fetch_ref;
    run_tests("magic", new_handle());

    # only enable this when handles are allowed to be shared across threads
    #{
    #    my @h = new_handle();
    #    threads->new(sub { run_tests("threads", @h) })->join; 
    #}
    threads->new(sub { run_tests("magic threads-h", new_handle()) })->join; 
}
else {
    diag("No threads available in this perl");
}

1;
