#!perl -w
use strict;

my $file = "dbixs_rev.h";
my $svnversion = `svnversion -n`;
my $is_make_dist;

if ($svnversion eq 'exported') {
    $svnversion = `svnversion -n ..`;
    if (-f "../MANIFEST.SKIP") {
        # presumably we're in a subdirectory because the user is doing a 'make dist'
        $is_make_dist = 1;
    }
    else {
        # presumably we're being run by an end-user because their file timestamps
        # got messed up
        print "Skipping regeneration of $file\n";
        utime(time(), time(), $file); # update modification time
        exit 0;
    }
}

my @warn;
die "Neither current directory nor parent directory are an svn working copy\n"
    unless $svnversion and $svnversion =~ m/^\d+/;
push @warn, "Mixed revision working copy"
    if $svnversion =~ s/:\d+//;
push @warn, "Code modified since last checkin"
    if $svnversion =~ s/[MS]+$//;
warn "$file warning: $_\n" for @warn;
die "$0 failed\n" if $is_make_dist && @warn;

write_header($file, DBIXS_REVISION => $svnversion, \@warn);

sub write_header {
    my ($file, $macro, $version, $comments_ref) = @_;
    open my $fh, ">$file" or die "Can't open $file: $!\n";
    print $fh "/* $_ */\n" for @$comments_ref;
    print $fh "#define $macro $version\n";
    close $fh or die "Error closing $file: $!\n";
    print "Wrote $macro $version to $file\n";
}
