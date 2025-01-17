#!/pro/bin/perl

use 5.038002;
use warnings;

our $VERSION = "0.05 - 20250116";
our $CMD = $0 =~ s{.*/}{}r;

sub usage {
    my $err = shift and select STDERR;
    say "usage: $CMD [-v[#]] [--pod]";
    exit $err;
    } # usage

use Cwd;
use Pod::Text;
use File::Find;
use List::Util   qw( first          );
use Encode       qw( encode decode  );
use Getopt::Long qw(:config bundling);
GetOptions (
    "help|?"		=> sub { usage (0); },
    "V|version"		=> sub { say "$CMD [$VERSION]"; exit 0; },

    "p|pod!"		=> \ my $pod,

    "v|verbose:1"	=> \(my $opt_v = 0),
    ) or usage (1);

-d "doc" or mkdir "doc", 0775;

my @pm;	# Do *NOT* scan t/
-d "lib" and find (sub { m/\.pm$/ and push @pm => $File::Find::name }, "lib");
@pm or @pm = sort glob "*.pm";
if (@pm == 0 and open my $fh, "<", "Makefile.PL") {
    my @mpl = <$fh>;
    close $fh;
    if (my @vf = grep m/\bVERSION_FROM\s*=>\s*(.*)/) {
	push @pm => $vf[0] =~ s/["']//gr;
	last;
	}
    if (my @ef = grep m/\bEXE_FILES\s*=>\s*\[(.*)\]/) {
	push @pm => eval qq{($1)};
	last;
	}
    }

push @pm => @ARGV;
@pm = sort grep { ! -l $_ } @pm;
@pm or die "No documentation source files found\n";

if ($opt_v) {
    say "Using these sources for static documentation:";
    say " $_" for @pm;
    }

sub dext {
    my ($pm, $ext) = @_;
    my $fn = $pm =~ s{^lib/}{}r
		 =~ s{^(?:App|scripts|examples)/}{}r
		 =~ s{/}{-}gr
		 =~ s{(?:\.pm)?$}{.$ext}r	# examples, scripts
		 =~ s{^(?=CSV_XS\.)}{Text-}r
		 =~ s{^(?=Peek\.)}  {Data-}r
		 =~ s{^(?=Read\.)}  {Spreadsheet-}r
		 =~ s{^(SpeedTest)} {\L$1}ri
		 =~ s{^}{doc/}r;
    getcwd =~ m/Config-Perl/ and
	$fn =~ s{doc/\K}{Config-Perl-};
    $fn;
    } # dext

my %enc;
my %pod;
{   # Check if file had pod at all
    foreach my $pm (@pm) {
	open my $fh, ">", \$pod{$pm};
	Pod::Text->new->parse_from_file ($pm, $fh);
	close $fh;

	$pod && $pod{$pm} and link $pm => dext ($pm, "pod");
	}
    }

eval { require Pod::Checker; };
if ($@) {
    warn "Cannot convert pod to markdown: $@\n";
    }
else {
    my $fail = 0;
    my %ignore_empty = (
	"lib/DBI/ProfileData.pm"	=> 7,
	"Peek.pm"			=> 4,
	"Read.pm"			=> 5,
	);
    foreach my $pm (@pm) {
	open my $eh, ">", \my $err;
	my $pc = Pod::Checker->new ();
	my $ok = $pc->parse_from_file ($pm, $eh);
	close $eh;
	$enc{$pm} = $pc->{encoding};
	$err && $err =~ m/\S/ or next;
	# Ignore warnings here on empty previous paragraphs as it
	# uses =head2 for all possible invocation alternatives
	if (my $ni = $ignore_empty{$pm}) {
	    my $pat = qr{ WARNING: empty section };
	    my @err = split m/\n+/ => $err;
	    my @wrn = grep m/$pat/ => @err;
	    @wrn == $ni and $err = join "\n" => grep !m/$pat/ => @err;
	    $err =~ m/\S/ or next;
	    }
	say $pm;
	say $err;
	$err =~ m/ ERROR:/ and $fail++;
	}
    $fail and die "POD has errors. Fix them first!\n";
    }

eval { require Pod::Markdown; };
if ($@) {
    warn "Cannot convert pod to markdown: $@\n";
    }
else {
    foreach my $pm (@pm) {
	my $md = dext ($pm, "md");
	my $enc = $enc{$pm} ? "encoding($enc{$pm})" : "bytes";
	printf STDERR "%-43s <- %s (%s)\n", $md, $pm, $enc if $opt_v;
	open my $ph, "<:$enc", $pm;
	my $p = Pod::Markdown->new ();
	$p->output_string (\my $m);
	$p->parse_file ($ph);
	close $ph;

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
	$pod{$pm} or next; # Skip HTML for files without pod
	my $html = dext ($pm, "html");
	printf STDERR "%-43s <- %s (%s)\n", $html, $pm, $enc{$pm} // "-" if $opt_v;
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
    unlink "pod2htmd.tmp";
    }

eval { require Pod::Man; };
if ($@) {
    warn "Cannot convert pod to man: $@\n";
    }
else {
    my $nrf = first { -x }
	      map   { "$_/nroff" }
	      grep { length and -d }
	      split m/:+/ => $ENV{PATH};
    $opt_v and say $nrf;
    foreach my $pm (@pm) {
	my $man = dext ($pm, "3");
	printf STDERR "%-43s <- %s\n", $man, $pm if $opt_v;
	open my $fh, ">", \my $p;
	Pod::Man->new (section => 3)->parse_from_file ($pm, $fh);
	close $fh;
	$p && $p =~ m/\S/ or next;
	$p = decode ("utf-8", $p);
	if (open my $old, "<:encoding(utf-8)", $man) {
	    local $/;
	    $p eq scalar <$old> and next;
	    }
	$opt_v and say "Writing $man (", length $p, ")";
	open my $oh, ">:encoding(utf-8)", $man or die "$man: $!\n";
	print $oh $p;
	close $oh;
	$nrf or next;
	if (open my $fh, "-|", $nrf, "-mandoc", "-T", "utf8", $man) {
	    local $/;
	    $p = <$fh>;
	    close $fh;
	    $p = decode ("utf-8", $p
		=~ s{(?:\x{02dc}|\xcb\x9c	)}{~}grx	# ~
		=~ s{(?:\x{02c6}|\xcb\x86	)}{^}grx	# ^
		=~ s{(?:\x{2018}|\xe2\x80\x98
		       |\x{2019}|\xe2\x80\x99	)}{'}grx	# '
		=~ s{(?:\x{201c}|\xe2\x80\x9c
		       |\x{201d}|\xe2\x80\x9d	)}{"}grx	# "
		=~ s{(?:\x{2212}|\xe2\x88\x92
		       |\x{2010}|\xe2\x80\x90	)}{-}grx	# -
		=~ s{(?:\x{2022}|\xe2\x80\xa2	)}{*}grx	# BULLET
		=~ s{(?:\e\[|\x9b)[0-9;]*m}	  {}grx);	# colors
	    }

	my $mfn = $man =~ s/3$/man/r;
	if (open my $mh, "<:encoding(utf-8)", $mfn) {
	    local $/;
	    $p eq <$mh> and next;
	    }
	$opt_v and say "Writing $mfn (", length $p, ")";
	open  $oh, ">:encoding(utf-8)", $mfn or die "$mfn: $!\n";
	# nroff / troff / grotty cause double-encoding
	print $oh encode ("iso-8859-1", decode ("utf-8", $p));
	close $oh;
	}
    }
