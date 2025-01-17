#!/pro/bin/perl

use 5.014002;
use warnings;

our $VERSION = "0.03 - 20250117";
our $CMD = $0 =~ s{.*/}{}r;

sub usage {
    my $err = shift and select STDERR;
    say "usage: $CMD ...";
    exit $err;
    } # usage

use autodie;
use Getopt::Long qw(:config bundling);
GetOptions (
    "help|?"		=> sub { usage (0); },
    "V|version"		=> sub { say "$CMD [$VERSION]"; exit 0; },

    "v|verbose:1"	=> \(my $opt_v = 0),
    ) or usage (1);

open my $ph, ">:encoding(utf-8)", "lib/DBI/Changes.pm";
open my $ch, "<:encoding(utf-8)", "ChangeLog";

my @m = qw( - Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
my @chg;
while (<$ch>) {
    s/[\s\r\n]+\z//;
    if (s/^([0-9]+(?:\.[.0-9]+))\s+//) {
	my ($v, $dt, $svn) = ($1);
	if (s/^[-,\s]*([0-9]{4})-([0-9]{2})-([0-9]{2})[-,\s]*//) {
	    $dt = "$3 $m[$2] $1";
	    }
	else {
	    $dt = "TBD";
	    }
	s/\s*\(?\s*svn\s+(?:rev |r)([0-9]+)\s*\)\s*$// and $svn = $1;
	push @chg => [ $v, $dt, $_, $svn || "" ];
	next;
	}
    push @{$chg[-1]} => $_;
    }
close $ch;

print $ph <<"EOH";
#!/usr/bin/perl

use strict;
use warnings;

1;

__END__
=head1 NAME

DBI::Changes - List of significant changes to the DBI

=encoding UTF-8

EOH

foreach my $c (@chg) {
    my @c = @$c;
    my ($vsn, $date, $author, $svn) = splice @c, 0, 4;
    $svn =~ s/([0-9]+)/ (svn rev $1)/;
    say $ph "=head2 Changes in DBI $vsn$svn - $date";
    say $ph "";
    shift @c while @c && $c[ 0] !~ m/\S/;
    pop   @c while @c && $c[-1] !~ m/\S/;
    if ($c[0] =~ s/^(\s*)(\*|\x{2022})\s*//) {
	my $ws = $1;
	s/^$ws// for @c;
	my @i = [ shift @c ];
	while (@c) {
	    if ($c[0] =~ s/^(\*|\x{2022})\s*//) {
		push @i => [ shift @c ]
		}
	    else {
		push @{$i[-1]} => shift @c;
		}
	    }
	say $ph "=over 2";
	for (@i) {
	    say $ph "";
	    say $ph "=item *";
	    say $ph "";
	    say $ph s/^\s+//r for @$_;
	    }

	say $ph "";
	say $ph "=back";
	}
    else {
	say $ph $_ for @c;
	}
    say $ph "";
    }

print $ph <<"EOF";
=head1 ANCIENT HISTORY

12th Oct 1994: First public release of the DBI module.
               (for Perl 5.000-beta-3h)

19th Sep 1994: DBperl project renamed to DBI.

29th Sep 1992: DBperl project started.

=cut
EOF
