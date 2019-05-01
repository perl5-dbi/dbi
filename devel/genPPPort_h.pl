#!/pro/bin/perl

use 5.12.1;
use warnings;

use Devel::PPPort;
use File::Copy;

# Check to see if Devel::PPPort needs updating
my $ph = "dbipport.h";

if (-f $ph) {
    my ($cv) = (qx{perl $ph --version} =~ m{\b([0-9]\.\w+)});
    if ($Devel::PPPort::VERSION lt $cv) {
	warn "Your $ph is newer than Devel::PPPort. Update skipped\n";
	}
    else {
	my $old = do { local (@ARGV, $/) = ($ph); <> };
	move $ph, "$ph.bkp";

	Devel::PPPort::WriteFile ($ph);

	my $new = do { local (@ARGV, $/) = ($ph); <> };

	if ($old ne $new) {
	    warn "$ph updated to $Devel::PPPort::VERSION\n";
	    unlink "$ph.bkp";
	    }
	else {
	    unlink $ph;
	    move "$ph.bkp", $ph;
	    }
	}
    }
else {
    Devel::PPPort::WriteFile ("$ph");
    warn "Installed new $ph $Devel::PPPort::VERSION\n";
    }

my $cv = "5.8.1";
if (open my $fh, "<", "Makefile.PL") {
    for (grep m/MIN_PERL_VERSION/ => <$fh>) {
	m/\b(5\.[0-9._]+)\b/ or next;
	my @v = split m/[._]/ => $1;
	$v[1] =~ m/^(\d\d\d)(.*)/ and splice @v, 1, 1, $1, $2;
	$v[2] ||= 0;
	$cv = join "." => map { $_ + 0 } @v;
	}
    }

warn "Checking against minimum perl version $cv\n";
my @ppp = qx{perl $ph --compat-version=$cv --quiet DBI.xs} or exit 0;

# Devel::PPPort does not take indirect includes into account :(
my (@ph, $phi);
if (open my $fh, "<", "DBIXS.h") {
    while (<$fh>) {
	push @ph, $_;
	m/^#include "$ph"$/ and $phi = @ph;
	}
    }
$ppp[$_] =~ s/\bDBI\.xs\b/DBIXS.h/ for 0, 1;
if (my @i = grep { $ppp[$_] =~ m/^\+#include "$ph"$/ } 0 .. $#ppp) {
    my $cf = $phi - 3;
    $ppp[$i[0]] =~ s/^\+/ /;
    $ppp[2] =~  s/ -\K1,(\d+)/sprintf " -%d,%d", $cf, $1 + 3/e;
    $ppp[2] =~ s/ \+\K1,(\d+)/sprintf " +%d,%d", $cf, $1 + 2/e;
    splice @ppp, $i[0] + 1, 3, map { $ph[$_] =~ s/^/ /r } $phi .. ($phi + 1);
    splice @ppp, 3, 0, map { $ph[$_] =~ s/^/ /r } ($cf - 1) .. ($cf + 1);
    }
warn
    "Devel::PPPort suggests the following change:\n",
    "--8<---\n",
    @ppp,
    "-->8---\n",
    "run 'perl $ph --compat-version=$cv DBI.xs' to see why\n";
