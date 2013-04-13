package DBI::Test::DBI::List;

use strict;
use warnings;

use parent qw(DBI::Test::List);

sub test_cases
{
    return qw(
	basic::sql_engine
	basic::dbd_file
	... dbd::dbm
    );
}

1;
