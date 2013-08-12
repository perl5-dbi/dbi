package DBI::Test::DBI::List;

use strict;
use warnings;

use parent qw(DBI::Test::List);

sub test_cases
{
    return map { "DBI::" . $_ } qw(
	simple::sql_engine
	simple::file
	simple::dbm
    );
}

1;
