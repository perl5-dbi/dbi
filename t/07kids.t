#!perl -w

use strict;
use Test;
use DBI;

BEGIN {

    if ($DBI::PurePerl) {
        print "1..0 # Skipped: \$h->{Kids} attribute not supported for DBI::PurePerl\n";
        exit 0;
    }

    plan tests => 9;
}
# Connect to the example driver.

ok( my $dbh = DBI->connect('dbi:ExampleP:dummy', '', '',
                           { PrintError => 0,
                             RaiseError => 0,
                             HandleError => \&test_kid
                           })
  );


# Raise an error.
my $x =eval { $dbh->do('select foo from foo') };

sub test_kid {
    my ($err, $dbh, $retval) = @_;
    # Testing $dbh->{Kids} here is unstable because we would be relying on
    # when perl chooses to call DESTROY the lexical $sth created within prepare()
    # The HandleError sub doesn't get called until the do() is returning
    # and recent perl's (>=5.8.0) have destroyed the handle by then (quite reasonably).

    # When a HandleEvent attribute gets added to the DBI then we'll probably call that
    # at the moment the error is registered, and so we could test $sth->{Kids} then.

    ok(1);
}

ok( $dbh->{Kids}, 0 );

my $drh = $dbh->{Driver};
ok( $drh->{Kids}, 1 );
ok( $drh->{ActiveKids}, 1 );

$dbh->disconnect;
ok( $drh->{Kids}, 1 );
ok( $drh->{ActiveKids}, 0 );

undef $dbh;
ok( $drh->{Kids}, 0 );
ok( $drh->{ActiveKids}, 0 );
