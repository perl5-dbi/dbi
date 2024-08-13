package DBI::Test::DBI::Conf;

use strict;
use warnings;

use parent qw(DBI::Test::Conf);

BEGIN
{
    eval { require SQL::Statement; };
}

my %setup = (
          pureperl => {
                        name         => "DBI::PurePerl",
                        category     => "dbi",
                        cat_abbrev   => "z",
                        abbrev       => "p",
                        init_stub    => [ '$ENV{DBI_PUREPERL} = 2', ],
                        cleanup_stub => ['delete $ENV{DBI_PUREPERL};'],
                      },
          gofer => {
              name       => "DBD::Gofer",
              category   => "dbi",
              cat_abbrev => "z",
              abbrev     => "g",
              init_stub => [ q{$ENV{DBI_AUTOPROXY} = 'dbi:Gofer:transport=null;policy=pedantic'}, ],
              cleanup_stub => [q|delete $ENV{DBI_AUTOPROXY};|],
          },
          (
            ( defined( $INC{'SQL/Statement.pm'} ) and -f $INC{'SQL/Statement.pm'} )
            ? (
                nano => {
                          name         => "DBI::SQL::Nano",
                          category     => "dbi",
                          cat_abbrev   => "z",
                          abbrev       => "n",
                          init_stub    => [ q{$ENV{DBI_SQL_NANO} = 1}, ],
                          cleanup_stub => [q|delete $ENV{DBI_SQL_NANO};|],
                        },
              )
            : ()
          ),
);

sub conf
{
    %setup;
}

1;
