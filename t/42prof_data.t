#!perl -w
use strict;

#
# test script for DBI::ProfileData
# 

use DBI;
use DBI::ProfileDumper;
use DBI::ProfileData;

BEGIN {
    if ($DBI::PurePerl) {
	print "1..0 # Skipped: profiling not supported for DBI::PurePerl\n";
	exit 0;
    }
}

use Test;
BEGIN { plan tests => 18; }

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Terse = 1;

my $sql = "select mode,size,name from ?";

my $dbh = DBI->connect("dbi:ExampleP:", '', '', 
                       { RaiseError=>1, Profile=>"6/DBI::ProfileDumper" });

# do a little work
foreach (1,2,3) {
  my $sth = $dbh->prepare($sql);
  for my $loop (1..20) {  
    $sth->execute(".");
    $sth->fetchrow_hashref;
    $sth->finish;
  }
  $sth->{Profile}->flush_to_disk();
}
$dbh->disconnect;
undef $dbh;


# wrote the profile to disk?
ok(-s "dbi.prof");

# load up
my $prof = DBI::ProfileData->new();
ok($prof);
ok(ref $prof eq 'DBI::ProfileData');

ok($prof->count() >= 3);

# try a few sorts
my $nodes = $prof->nodes;
$prof->sort(field => "longest");
my $longest = $nodes->[0][4];
ok($longest);
$prof->sort(field => "longest", reverse => 1);
ok($nodes->[0][4] < $longest);

$prof->sort(field => "count");
my $most = $nodes->[0];
ok($most);
$prof->sort(field => "count", reverse => 1);
ok($nodes->[0][0] < $most->[0]);

# remove the top count and make sure it's gone
my $clone = $prof->clone();
$clone->sort(field => "count");
ok($clone->exclude(key1 => $most->[7]));

# compare keys of the new first element and the old one to make sure
# exclude works
ok($clone->nodes()->[0][7] ne $most->[7] &&
   $clone->nodes()->[0][8] ne $most->[8]);

# there can only be one
$clone = $prof->clone();
ok($clone->match(key1 => $clone->nodes->[0][7]));
ok($clone->match(key2 => $clone->nodes->[0][8]));
ok($clone->count == 1);

# take a look through Data
my $Data = $prof->Data;
ok(exists($Data->{$sql}));
ok(exists($Data->{$sql}{execute}));

# test escaping of \n and \r in keys
$dbh = DBI->connect("dbi:ExampleP:", '', '', 
                    { RaiseError=>1, Profile=>"6/DBI::ProfileDumper" });

my $sql2 = 'select size from . where name = "LITERAL: \r\n"';
my $sql3 = "select size from . where name = \"EXPANDED: \r\n\"";

# do a little work
foreach (1,2,3) {
  my $sth2 = $dbh->prepare($sql2);
  $sth2->execute();
  $sth2->fetchrow_hashref;
  $sth2->finish;
  my $sth3 = $dbh->prepare($sql3);
  $sth3->execute();
  $sth3->fetchrow_hashref;
  $sth3->finish;
}
undef $dbh;

# load dbi.prof
$prof = DBI::ProfileData->new();
ok($prof and ref $prof eq 'DBI::ProfileData');

# make sure the keys didn't get garbled
$Data = $prof->Data;
ok(exists $Data->{$sql2});
ok(exists $Data->{$sql3});

# cleanup
# unlink("dbi.prof"); # now done by 'make clean'

