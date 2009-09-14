#!/pro/bin/perl

use strict;
use warnings;

use File::Find;
#use DateTime;
use DateTime::Format::DateParse;

find (sub {
    -f $_ && $_ =~ m/\.pm$/ or return;
    my $f = $_;
    my $pm = do { local (@ARGV, $/) = ($_); scalar <> };
    $pm =~ m/\$(Id|Revision)\$/ or return;
    open my $gl, "-|", "git log -1 $f";
    my ($svn_id, $svn_date, $svn_author) = ("", "");
    while (<$gl>) {
	m/git-svn-id:.*?trunk\@([0-9]+)/	and $svn_id	= $1;
	m/^Date:\s*(.*)/			and $svn_date	= $1;
	m/^Author:\s*(\S+)/			and $svn_author	= $1;
	}
    $svn_id or return;

    my $dt = DateTime::Format::DateParse->parse_datetime ($svn_date);
    $dt = $dt->ymd . " " . $dt->hms . "Z";
    $pm =~ s/\$Revision\$/\$Revision: $svn_id \$/g;
    $pm =~ s/\$Id\$/\$Id: $f $svn_id $dt $svn_author \$/g;

    my @st = stat $f;
    unlink $f;
    open my $fh, ">", $f or die "Cannot update $File::Find::name: $!\n";
    print $fh $pm;
    close $fh;
    utime $st[8], $st[9], $f;
    }, "lib");
