#!/usr/bin/perl

use 5.026001;
use warnings;

package Evil::db;

our @ISA = ("DBD::SQLite::db");

use strict;
use warnings;

sub prepare {
    return bless {}, "Evil::st";  # blessed HV, no P magic
    } # prepare

package Evil::st;

our @ISA = ("DBD::SQLite::st");

use strict;
use warnings;

sub can { 1 }

package main;

use strict;
use warnings;

use DBI;

my $dbh = DBI->connect ("dbi:SQLite::memory:", "", "", {
    RaiseError => 0,
    PrintError => 0,
    });
bless $dbh, "Evil::db";
$dbh->selectall_arrayref ("select 1");  # SEGV
