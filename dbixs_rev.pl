#!/usr/bin/perl

use strict;
use warnings;

my $dbixs_rev_file = "dbixs_rev.h";

sub skip_update {
    my $reason = shift;
    print "Skipping regeneration of $dbixs_rev_file: ", $reason, "\n";
    utime (time (), time (), $dbixs_rev_file); # update modification time
    exit 0;
    } # skip_update

-d ".git" or skip_update ("No git env");

my ($dbiv, $dbir);
open my $fh, "<", "DBI.pm" or die "DBI.pm: $!\n";
while (<$fh>) {
    m/\b VERSION \s*=\s* (["']) ([0-9]+) \. ([0-9]+) \1/x or next;
    ($dbiv, $dbir) = ($2, $3);
    close $fh;
    last;
    }
$dbiv or die "Cannot fetch DBI version from DBI.pm\n";

my @n = eval { qx{git log --pretty=oneline} };
@n or skip_update ("Git log was empty");

open $fh, ">$dbixs_rev_file" or die "Can't open $dbixs_rev_file: $!\n";
print $fh "/* ", scalar localtime, " */\n";

chomp (my @st = qx{git status -s --show-stash});
print $fh "/* $_ */\n" for grep { !m/\b$dbixs_rev_file\b/ } @st;

my $def = "DBIXS_REVISION";
my $rev = scalar @n;
print $fh "#define DBIXS_VERSION  $dbiv\n";
print $fh "#define DBIXS_RELEASE  $dbir\n";
print $fh "#define $def $rev\n";
close $fh or die "Error closing $dbixs_rev_file: $!\n";
print "Wrote $def $rev to $dbixs_rev_file for DBI-$dbiv.$dbir\n";
