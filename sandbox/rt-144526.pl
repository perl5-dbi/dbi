use strict;
use warnings;
use Test::More;
use DBI;

my $runN = shift;

package Foo {
    our $count;

    sub new {
	my ($class) = @_;
	++$count;
	return bless {}, $class;
	} # new
    sub DESTROY { --$count }
    }

sub run_the_test {
    my ($dbh, $clear) = @_;

    $Foo::count = 0;

    do {
	for (Foo->new) {
	    is ($Foo::count, 1, '1 Foo should have been created');

	    $dbh->ping;
	    }
	$clear and delete $dbh->{Callbacks}{ping};
	};
    is ($Foo::count, 0, 'all Foo should have been destroyed');
    } # run_the_test

subtest 'without callbacks' => sub {
    my $dbh = DBI->connect ('DBI:SQLite:dbname=:memory:',);

    run_the_test ($dbh);
    };

subtest 'with callbacks' => sub {
    my $dbh = DBI->connect ('DBI:SQLite:dbname=:memory:',);
    $dbh->{Callbacks}{ping} = sub { };

    run_the_test ($dbh);
    };

subtest 'with callbacks C' => sub {
    my $dbh = DBI->connect ('DBI:SQLite:dbname=:memory:',);
    $dbh->{Callbacks}{ping} = sub { };

    run_the_test ($dbh, 1);
    };

$runN and
subtest 'with callbacks N' => sub {
    my $dbh = DBI->connect ('DBI:SQLite:dbname=:memory:',);
    $dbh->{Callbacks}{ping} = undef;

    run_the_test ($dbh);
    };

done_testing;
