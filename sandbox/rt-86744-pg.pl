#!/pro/bin/perl

use strict;
use warnings;

use DBI;
use DBD::Pg;

my $count = $ARGV[0] || 1;

print "DBI-$DBI::VERSION, DBD::Pg-$DBD::Pg::VERSION, count: $count\n";

my $place_holders = join (",", ("?") x $count);

my $sql = <<"EOF";
select *
from   information_schema.tables
where  table_schema in ($place_holders)
EOF

my @params = ("test") x $count;

my $dbh = DBI->connect ("DBI:Pg:", undef, undef, {
    Callbacks => { ChildCallbacks => { execute => sub { return; } }}});

my $sth = $dbh->prepare ($sql);
$sth->execute (@params);
