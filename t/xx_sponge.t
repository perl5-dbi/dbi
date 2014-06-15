#! /usr/bin/env perl

# vim: noet ts=2 sw=2:

use strict;
use warnings;
use Test::More tests => 17;

use Storable qw(dclone);
use DBI qw(:sql_types);

our @ROWS = (['foo',     undef,       'bazooka'],
             ['foolery', 'bar',       undef    ],
             [undef,     'barrowman', 'baz'    ]);

my $dbh = DBI->connect("dbi:Sponge:", '', '');
ok($dbh, "connect(dbi:Sponge:) succeeds");

my $sth = $dbh->prepare("simple, correct sponge", {
                        rows => dclone( \@ROWS ),
                        NAME => [ qw(A0 B1 C2) ],
                        });

ok($sth, "prepare() of 3x3 result succeeded");
is_deeply($sth->{NAME}, ['A0', 'B1', 'C2'], "column NAMEs as expected");
is_deeply($sth->{TYPE}, [SQL_VARCHAR, SQL_VARCHAR, SQL_VARCHAR],
          "column TYPEs default to SQL_VARCHAR");
is_deeply($sth->{PRECISION}, [7, 9, 7],
          "column PRECISION matches lengths of longest field data");
is_deeply($sth->fetch(), $ROWS[0], "first row fetch as expected");
is_deeply($sth->fetch(), $ROWS[1], "second row fetch as expected");
is_deeply($sth->fetch(), $ROWS[2], "third row fetch as expected");
ok(!defined($sth->fetch()), "fourth fetch returns undef");


$sth = $dbh->prepare('user-supplied silly TYPE and PRECISION', {
                     rows => dclone( \@ROWS ),
                     NAME => [qw( first_col second_col third_col )],
                     TYPE => [SQL_INTEGER, SQL_DATETIME, SQL_CHAR],
                     PRECISION => [1, 100_000, 0],
                     });
ok($sth, "prepare() 3x3 result with TYPE and PRECISION succeeded");
is_deeply($sth->{NAME}, ['first_col','second_col','third_col'],
          "column NAMEs again as expected");
is_deeply($sth->{TYPE}, [SQL_INTEGER, SQL_DATETIME, SQL_CHAR],
          "column TYPEs not overwritten");
is_deeply($sth->{PRECISION}, [1, 100_000, 0],
          "column PRECISION not overwritten");
is_deeply($sth->fetch(), $ROWS[0], "first row fetch as expected, despite bogus attributes");
is_deeply($sth->fetch(), $ROWS[1], "second row fetch as expected, despite bogus attributes");
is_deeply($sth->fetch(), $ROWS[2], "third row fetch as expected, despite bogus attributes");
ok(!defined($sth->fetch()), "fourth fetch returns undef, despite bogus attributes");
