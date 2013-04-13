package DBI::Test::DBI::Conf;

use strict;
use warnings;

use parent qw(DBI::Test::Conf);

my %setup = (
	p => {	name => "DBI::PurePerl",
		match => qr/^\d/,
		add => [ '$ENV{DBI_PUREPERL} = 2',
			 'END { delete $ENV{DBI_PUREPERL}; }' ],
	},
	g => {	name => "DBD::Gofer",
		match => qr/^\d/,
		add => [ q{$ENV{DBI_AUTOPROXY} = 'dbi:Gofer:transport=null;policy=pedantic'},
			 q|END { delete $ENV{DBI_AUTOPROXY}; }| ],
	},
	n => {	name => "DBI::SQL::Nano",
		match => qr/^(?:48dbi_dbd_sqlengine|49dbd_file|5\ddbm_\w+|85gofer)\.t$/,
		add => [ q{$ENV{DBI_SQL_NANO} = 1},
			 q|END { delete $ENV{DBI_SQL_NANO}; }| ],
	},
);

sub setup
{
    %setup;
}

1;
