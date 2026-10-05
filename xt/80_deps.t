#!/pro/bin/perl

use 5.012000;
use warnings;

use Test::More;

eval { require CPAN::Meta; };
if ($@) {
    say "1..0 # CPAN::Meta not available";
    exit 0;
    }

BEGIN { $V::NO_EXIT = $V::NO_EXIT = 1 }
eval { require V; };
if ($@) {
    say "1..0 # V not available";
    exit 0;
    }

my @cleanup;
unless (-s "META.yml") {
    eval { system "perl sandbox/genMETA.pl >/dev/null 2>&1"; };
    unless (-s "META.yml") {
	say "1..0 # No META.yml";
	exit  0;
	}
    push @cleanup => "META.json", "META.yml";
    }
END { unlink $_ for @cleanup; }

my $meta = CPAN::Meta->load_file ("META.yml");
note join " - " => $meta->name, $meta->version;

my $prereqs = $meta->effective_prereqs;
for my $phase (qw( configure runtime build test )) {
    my $reqs = $prereqs->requirements_for ($phase, "requires");
    for my $module (sort $reqs->required_modules) {
	my $vsn = $module eq "perl" ? $] : V::get_version ($module);
	if (defined $vsn) {
	    ok ($reqs->accepts_module ($module, $vsn), "$module-$vsn for $phase");
	    }
	else {
	    ok (0, "$module not found, required for $phase");
	    }
	}
    }

if (my $reqs = $prereqs->requirements_for ("runtime", "conflicts")) {
    for my $module (sort $reqs->required_modules) {
	my $vsn = V::get_version ($module);
	if (defined $vsn) {
	    ok (!$reqs->accepts_module ($module, $vsn), "$module-$vsn does not conflict");
	    }
	else {
	    note "$module is not installed";
	    }
	}
    }

done_testing;
