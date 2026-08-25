#!/pro/bin/perl

use strict;
use warnings;

use DBI;
use DBD::mysql;

my $count = $ARGV[0] || 1;

print "DBI-$DBI::VERSION, DBD::mysql-$DBD::mysql::VERSION, count: $count\n";

my $place_holders = join (",", ("?") x $count);

my $sql = <<"EOF";
select *
from   information_schema.tables
where  table_schema in ($place_holders)
EOF

my @params = ("test") x $count;

my $dbh = DBI->connect ("DBI:mysql:test", q{}, q{}, {
    Callbacks => { ChildCallbacks => { execute => sub { return; } }}});

my $sth = $dbh->prepare ($sql);
$sth->execute (@params);
