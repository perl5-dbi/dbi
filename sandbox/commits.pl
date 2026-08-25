#!/pro/bin/perl

use 5.014002;
use warnings;

our $VERSION = "0.01 - 20241014";
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

    "v|verbose:1"	=> \(my $opt_v = 0),
    ) or usage (1);

my %a;
#my ($out, $err, $ext) = capture {
#    system "git log --pretty=format:%ai,%aN | cat";
#    };
#for (split m/\n/ => $out) {
open my $fh, "-|", "git", "log", "--pretty=format:%ai,%aN";
while (<$fh>) {
    s/[\s\r\n]+\z//;
    my ($d, $a) = m/^([0-9]{4}-[0-9][0-9])-\d+.*?,\s*(.*)/;
    unless ($d) {
	say;
	next;
	}
    $a =~ s/\s*-\s*Tux.*//i;
    $a{decode ("utf-8", $a)}{$d}++;
    #print;
    }
close $fh;

my %h;
my $nn = 0;
binmode STDOUT, ":encoding(utf-8)";
foreach my $a (sort keys %a) {
    my %d = %{$a{$a}};
    my @d = sort keys %d;
    my $N = sum values %d;
    $nn += $N;
    $N > 2 or next;
    $h{$d[0]}{$N}{$a} = $d[-1];
    }
foreach my $start (sort keys %h) {
    foreach my $n (sort { $b <=> $a } keys %{$h{$start}}) {
	foreach my $a (sort keys %{$h{$start}{$n}}) {
	    printf "%s - %s %4d %3d%% %s\n",
		$start, $h{$start}{$n}{$a}, $n, lround (100. * $n / $nn), $a;
	    }
	}
    }
