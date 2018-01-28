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
use warnings;
use Test::More;
use DBI;

my $warning;

$SIG{__WARN__} = sub { $warning = $_[0] };

my $dbh = DBI->connect('dbi:NullP:', '', '', {PrintWarn => 1});

is $warning, undef, 'initially not set';

$dbh->set_err("0", "warning plain");
like $warning, qr/^DBD::\w+::db set_err warning: warning plain/, "Warning recorded by store";

$dbh->set_err(undef, undef);
undef $warning;

$dbh->set_err("0", "warning \N{U+263A} smiley face");
like $warning, qr/^DBD::\w+::db set_err warning: warning \x{263A} smiley face/, "Warning recorded by store"
    or warn DBI::data_string_desc($warning);

done_testing;
