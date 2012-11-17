#!/pro/bin/perl

use strict;
use warnings;

use File::Find;
use DateTime::Format::DateParse;

open my $ml, ">>", "git-svn-modlist";

find (sub {
    -f $_ && $_ =~ m/\.pm$/ or return;
    my $f = $_;
    my $pm = do { local (@ARGV, $/) = ($_); scalar <> };
    #print STDERR "$File::Find::name (@{[length $pm]})\n";
    $pm =~ m/\$(Id|Revision)\$/ or return;
    #print STDERR "$File::Find::name ...\n";
    open my $gl, "-|", "git log -1 $f";
    my ($svn_id, $svn_date, $svn_author) = ("", "");
    while (<$gl>) {
	m/git-svn-id:.*?(?:trunk|sqlengine)\@([0-9]+)/	and $svn_id	= $1;
	m/^Date:\s*(.*)/				and $svn_date	= $1;
	m/^Author:\s*(\S+)/				and $svn_author	= $1;
	}
    #print STDERR "  + $svn_id, $svn_author, $svn_date\n";
    $svn_id or return;

    my $dt = DateTime::Format::DateParse->parse_datetime ($svn_date);
    $dt = $dt->ymd . " " . $dt->hms . "Z";
    $pm =~ s/\$Revision\$/\$Revision: $svn_id \$/g;
    $pm =~ s/\$Id\$/\$Id: $f $svn_id $dt $svn_author \$/g;

    my @st = stat $f;
    unlink $f, "blib/$f";	# Remove both lib and blib version
    open my $fh, ">", $f or die "Cannot update $File::Find::name: $!\n";
    print $fh $pm;
    close $fh;
    utime $st[8], $st[9], $f;

    print $ml "$File::Find::name\n";
    }, "lib");

__END__

=head1 NAME

git-svn-vsn.pl - fill in the gaps from svn that git doesn't know about

=head1 SYNOPSYS

 $ git-svn-vsn.pl
 $ git chechout `cat git-svn-modlist`

=head1 DESCRIPTION

git has no concept of keywords that have special meaning like %R% in SCCS
or $Revision$ in rcv and svn. Most module files in DBI will en up with lines
like:

	$VERSION = sprintf("12.%06d", q$Revision$ =~ /(\d+)/o);

    #   $Id$

Running C<git-svn-vsn.pl> will read the git log for this file and convert it
to something like

	$VERSION = sprintf("12.%06d", q$Revision: 9215 $ =~ /(\d+)/o);

    #   $Id: NullP.pm 9215 2007-03-08 17:03:58Z timbo $

Which means that the C<$VERSION> veriables now actually make sense. As a side
effect, the script also drops a list with all the modules it changed, so the
C<make test> can revert to the actual files from the repository after the tests
have been run with C<git checkout `cat git-svn-modlist`>.

The call to C<git-svn-vsn.pl> is integrated in C<Makefile.PL> Before you can
push up the committed changes with C<svn dcommit --username committer>, you will
have te revert the changes to the modules by doing a checkout of the changed
files. Their names were stored in C<git-svn-modlist>.

=head1 SEE ALSO

git (1), svn (1)

=head1 AUTHOR

H.Merijn Brand <h.m.brand at xs4all.nl>

=head1 COPYRIGHT

None. Feel free to use this in any way you like

=cut
