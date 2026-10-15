#!/pro/bin/perl

use 5.014002;
use warnings;

our $VERSION = "0.01 - 20261015";
our $CMD = $0 =~ s{.*/}{}r;

sub usage {
    my $err = shift and select STDERR;
    say "usage: $CMD ...";
    exit $err;
    } # usage

use DBI;
use Getopt::Long qw(:config bundling);
GetOptions (
    "help|?"		=> sub { usage (0); },
    "V|version"		=> sub { say "$CMD [$VERSION]"; exit 0; },

    "v|verbose:1"	=> \(my $opt_v = 0),
    ) or usage (1);

my $dbh = DBI->connect ("dbi:SQLite::memory:", "", "", { RaiseError => 1 });
$dbh->sqlite_create_function ("grow", 1, sub { my @x = (0) x $_[0]; "row" });
say $dbh->selectrow_array ("select grow (100000)") // "undef";    # undef, expected 'row'
