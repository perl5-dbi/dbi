#!perl -w
use strict;

#
# test script for DBI::ProfileDumper
# 

use DBI;
use DBI::ProfileDumper;

BEGIN {
    if ($DBI::PurePerl) {
	print "1..0 # Skipped: profiling not supported for DBI::PurePerl\n";
	exit 0;
    }
}

use Test;
BEGIN { plan tests => 7; }

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Terse = 1;

my $dbh = DBI->connect("dbi:ExampleP:", '', '', 
                       { RaiseError=>1, Profile=>"DBI::ProfileDumper" });
ok(ref $dbh->{Profile}, "DBI::ProfileDumper");
ok(ref $dbh->{Profile}{Data}, 'HASH');
ok(ref $dbh->{Profile}{Path}, 'ARRAY');

# do a little work
my $sql = "select mode,size,name from ?";
my $sth = $dbh->prepare($sql);
$sth->execute(".");

$sth->{Profile}->flush_to_disk();
while ( my $hash = $sth->fetchrow_hashref ) {}

# force output
undef $sth;
$dbh->disconnect;
undef $dbh;

# wrote the profile to disk?
ok(-s "dbi.prof");

open(PROF, "dbi.prof") or die $!;
my $prof = join('', <PROF>);
close PROF;

# has a header?
ok($prof =~ /^DBI::ProfileDumper\s+([\d.]+)/);

# version matches VERSION?
ok($1, $DBI::ProfileDumper::VERSION);

# check that expected key is there
ok($prof =~ /\+\s+1\s+\Q$sql\E/m);

# unlink("dbi.prof"); # now done by 'make clean'

