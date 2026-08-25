#!/pro/bin/perl

use 5.014002;
use warnings;

our $VERSION = "0.01 - 20241015";
our $CMD = $0 =~ s{.*/}{}r;

sub usage {
    my $err = shift and select STDERR;
    say "usage: $CMD ...";
    exit $err;
    } # usage

use CSV;
#se Capture::Tiny qw( capture );
use POSIX         qw( lround         );
use Encode        qw( encode decode  );
use List::Util    qw( sum            );
use Getopt::Long  qw(:config bundling);
GetOptions (
    "help|?"		=> sub { usage (0); },
    "V|version"		=> sub { say "$CMD [$VERSION]"; exit 0; },

    "h|html!"		=> \ my $opt_h,

    "v|verbose:1"	=> \(my $opt_v = 0),
    ) or usage (1);

my (%r, %d);
open my $fh, "-|", "git", "log", "--pretty=format:%ai,%(describe:tags=1)";
while (<$fh>) {
    s/[\s\r\n]+\z//;
    my ($d, $t, $c) = m/^([-0-9]+).*?,\s*(?:DBI-)?(.*?)(?:-([0-9]+)-g[0-9a-f]+)?$/;
    unless ($d) {
	say;
	next;
	}
    $r{$t} ||= $c;
    $d{$t} = $d;
    }
close $fh;

foreach my $t (sort { $b cmp $a } keys %r) {
    $t =~ m/^(.*)_[0-9]+$/ or next;
    my $T = $1;
    $r{$T} += $r{$T} || 0;
    $d{$T} ||= $d{$t};
    }

#DDumper \%r;
foreach my $t (sort { $b cmp $a } keys %r) {
    $t =~ m/_/ and next;
    if ($opt_h) {
	next;
	}
    printf "%s %-8s %4s\n", $d{$t}, $t, $r{$t} // "-";
    }
