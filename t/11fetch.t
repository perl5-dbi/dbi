#!perl -w
# vim:ts=8:sw=4

use Test::More;
use DBI;
use Storable qw(dclone);
use Data::Dumper;

$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Quotekeys = 0;

plan tests => 12;

$dbh = DBI->connect("dbi:Sponge:foo","","", {
        PrintError => 0,
        RaiseError => 1,
});

my $source_rows = [ # data for DBD::Sponge to return via fetch
    [ 41,	"AAA",	9	],
    [ 41,	"BBB",	9	],
    [ 42,	"BBB",	undef	],
    [ 43,	"ccc",	7	],
    [ 44,	"DDD",	6	],
];

sub go {
    my $sth = $dbh->prepare("foo", {
	rows => dclone($source_rows),
	NAME => [ qw(C1 C2 C3) ],
    });
    ok($sth->execute(), $DBI::errstr);
    return $sth;
}

my($sth, $col0, $col1, $col2, $rows);

# --- fetchrow_arrayref
# --- fetchrow_array
# etc etc

# --- fetchall_hashref
my @fetchall_hashref_results = (
  C1 => {
    41  => { C1 => 41, C2 => 'BBB', C3 => 9 },
    42  => { C1 => 42, C2 => 'BBB', C3 => undef },
    43  => { C1 => 43, C2 => 'ccc', C3 => 7 },
    44  => { C1 => 44, C2 => 'DDD', C3 => 6 }
  },
  C2 => {
    AAA => { C1 => 41, C2 => 'AAA', C3 => 9 },
    BBB => { C1 => 42, C2 => 'BBB', C3 => undef },
    DDD => { C1 => 44, C2 => 'DDD', C3 => 6 },
    ccc => { C1 => 43, C2 => 'ccc', C3 => 7 }
  },
#  [ 'C1' ] => undef,
#  [ 'C2' ] => undef,
#  [ 'C1', 'C2' ] => undef,
);

while (my $keyfield = shift @fetchall_hashref_results) {
    my $expected = shift @fetchall_hashref_results;
    my $k = (ref $keyfield) ? "[@$keyfield]" : $keyfield;
    diag "fetchall_hashref($k)";
    ok($sth = go);
    my $result = $sth->fetchall_hashref($keyfield);
    ok($result);
    is_deeply($result, $expected);
$h{$k} = dclone $result;
}

#warn Dumper \%h;


# end
