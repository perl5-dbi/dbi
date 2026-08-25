#!/usr/bin/perl

use 5.026002;
use warnings;

use DBI;
use Data::Peek;

my $dbn = getpwuid $<;
my $dbh = DBI->connect ("DBI:MariaDB:dbname=$dbn");

my $TABLE_NAME = "_test_dbi_lasth";

$dbh->do (qq{create table $TABLE_NAME (foo char (5))});

{   my $sth = $dbh->prepare_cached (
	qq{select foo from $TABLE_NAME where foo = ?});
    $sth->bind_param (1, "bar");
    $sth->execute ();

    DBI->trace (99);
    DDumper { pv => [ sort { $a <=> $b } keys %{$sth->{ParamValues}} ]};
    DBI->trace (0);
    $sth->finish ();
    }

warn "=" x 50, "\n";
my $lasth = $DBI::lasth;
DBI->trace (99);
DDumper { keys => [ keys %{$lasth->{ParamValues}} ]};
DBI->trace ("0");

{   my $sth = $dbh->prepare_cached (
	qq{select foo from $TABLE_NAME where foo = ?});
    $sth->bind_param (1, "bar");
    $sth->execute ();

    DBI->trace (99);
    DDumper { pv => [ sort { $a <=> $b } keys %{$sth->{ParamValues}} ]};
    DBI->trace (0);
    $sth->finish ();
    }

$dbh->do (qq{drop table $TABLE_NAME});
