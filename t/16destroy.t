#!perl -w

use strict;

use Test::More tests => 14;

BEGIN{ use_ok( 'DBI' ) }

my $dsn = 'dbi:ExampleP:dummy';

# Connect to the example driver.
ok my $dbh = DBI->connect($dsn, '', ''),
    'Create plain dbh';

isa_ok( $dbh, 'DBI::db' );

# Clean up when we're done.
END { $dbh->disconnect if $dbh };

ok $dbh->{Active}, 'Should start active';
$dbh->DESTROY;
ok $dbh->{Active}, 'Should still be active';

# Try InactiveDestroy.
ok $dbh = DBI->connect($dsn, '', '', { InactiveDestroy => 1 }),
    'Create with ActiveDestroy';
ok $dbh->{Active}, 'Should start active';
$dbh->DESTROY;
ok !$dbh->{Active}, 'Should no longer be active';

# Try AutoInactiveDestroy.
ok $dbh = DBI->connect($dsn, '', '', { AutoInactiveDestroy => 1 }),
    'Create with AutoInactiveDestroy';
ok $dbh->{Active}, 'Should start active';
$dbh->DESTROY;
ok $dbh->{Active}, 'Should still be active';

# Try AutoInactiveDestroy and "fork".
ok $dbh = DBI->connect($dsn, '', '', { AutoInactiveDestroy => 1 }),
    'Create with AutoInactiveDestroy again';
ok $dbh->{Active}, 'Should start active';
do {
    # Fake fork.
    local $$ = 0;
    $dbh->DESTROY;
};
ok !$dbh->{Active}, 'Should not still be active';
