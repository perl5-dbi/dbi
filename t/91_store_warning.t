# Test if a warning can be recorded in the STORE method
# which it couldn't in DBI 1.628
# see https://rt.cpan.org/Ticket/Display.html?id=89015
# This is all started from the fact that the SQLite ODBC Driver cannot set the
# ReadOnly attribute (which is mapped to ODBC SQL_ACCESS_MODE) - it
# legitimately returns SQL_SUCCESS_WITH_INFO option value changed.
# It was decided that this should record a warning but when it was added to DBD::ODBC
# DBI did not show the warning - keep_err?
# Tim's comment on #dbi was:
#  the dispatcher has logic to notice if ErrCount went up during a call and disables keep_err in that case.
# I think something similar might be needed for err. E.g., "if it's defined now but wasn't defined before" then
# act appropriately.
use strict;
use Test::More;
use warnings;
use DBI;

my $warning;

$SIG{__WARN__} = sub {
    $warning = $_[0];
};

plan tests => 1;

my $dbh = DBI->connect('dbi:NullP:', '', '', {PrintWarn => 1});

$dbh->set_err("0", "warning");
#$dbh->{nullp_set_err} = '0';    # sets a warning with err msg "0"
#warn('fred'); # this would make this test succeed when DBI doesn't issue the warning
ok($warning, "Warning recorded by store");
