#!/pro/bin/perl

use 5.040000;
use warnings;

our $VERSION = "0.01 - 20240812";
our $CMD = $0 =~ s{.*/}{}r;

sub usage {
    my $err = shift and select STDERR;
    say "usage: $CMD [-v[#]]";
    exit $err;
    } # usage

use List::Util   qw( first );
use Getopt::Long qw(:config bundling);
GetOptions (
    "help|?"		=> sub { usage (0); },
    "V|version"		=> sub { say "$CMD [$VERSION]"; exit 0; },

    "v|verbose:1"	=> \(my $opt_v = 0),
    ) or usage (1);

my @pm = sort "DBI.pm",
	(glob "lib/*/*.pm"),
	(glob "lib/*/*/*.pm"),
	(glob "lib/*/*/*/*.pm");

eval { require Pod::Markdown; };
if ($@) {
    warn "Cannot convert pod to markdown: $@\n";
    }
else {
    foreach my $pm (@pm) {
	my $md = $pm =~ s{^lib/}{}r =~ s{/}{::}gr =~ s{\.pm$}{.md}r =~ s{^}{doc/}r;
	printf STDERR "%-43s <- %s\n", $md, $pm if $opt_v;
	open my $ph, "<:bytes", $pm;
	open my $mh, ">:bytes", \my $m;
	my $p = Pod::Markdown->new ();
	$p->output_fh  ($mh);
	$p->parse_file ($ph);
	close $ph;
	close $mh;

	$m && $m =~ m/\S/ or next;
	if (open my $old, "<:encoding(utf-8)", $md) {
	    local $/;
	    $m eq scalar <$old> and next;
	    }
	$opt_v and say "Writing $md (", length $m, ")";
	open my $oh, ">:encoding(utf-8)", $md or die "$md: $!\n";
	print $oh $m;
	close $oh;
	}
    }

eval { require Pod::Html; };
if ($@) {
    warn "Cannot convert pod to HTML: $@\n";
    }
else {
    foreach my $pm (@pm) {
	my $html = $pm =~ s{^lib/}{}r =~ s{/}{::}gr =~ s{\.pm$}{.html}r =~ s{^}{doc/}r;
	printf STDERR "%-43s <- %s\n", $html, $pm if $opt_v;
	my $tf = "x_$$.html";
	unlink $tf if -e $tf;
	Pod::Html::pod2html ("--infile=$pm", "--outfile=$tf", "--quiet");
	my $h = do { local (@ARGV, $/) = ($tf); <> } =~ s/[\r\n\s]+\z/\n/r;
	unlink $tf if -e $tf;
	$h && $h =~ m/\S/ or next;
	if (open my $old, "<:encoding(utf-8)", $html) {
	    local $/;
	    $h eq scalar <$old> and next;
	    }
	$opt_v and say "Writing $html (", length $h, ")";
	open my $oh, ">:encoding(utf-8)", $html or die "$html: $!\n";
	print $oh $h;
	close $oh;
	}
    }

eval { require Pod::Man; };
if ($@) {
    warn "Cannot convert pod to man: $@\n";
    }
else {
    foreach my $pm (@pm) {
	my $man = $pm =~ s{^lib/}{}r =~ s{/}{::}gr =~ s{\.pm$}{.3}r =~ s{^}{doc/}r;
	printf STDERR "%-43s <- %s\n", $man, $pm if $opt_v;
	open my $fh, ">", \my $p;
	Pod::Man->new (section => 3)->parse_from_file ($pm, $fh);
	close $fh;
	$p && $p =~ m/\S/ or next;
	if (open my $old, "<:encoding(utf-8)", $man) {
	    local $/;
	    $p eq scalar <$old> and next;
	    }
	$opt_v and say "Writing $man (", length $p, ")";
	open my $oh, ">:encoding(utf-8)", $man or die "$man: $!\n";
	print $oh $p;
	close $oh;
	}
    }
