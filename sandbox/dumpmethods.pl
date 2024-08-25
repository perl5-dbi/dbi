#!/usr/bin/perl

package DBI;

use strict;
use warnings;


BEGIN { $ENV{DBI_PUREPERL} = 2 }
use DBI;
use Data::Dumper;

no strict qw(subs refs); # build name and code to value mappings introspectively
my @ima_n   = grep { m/^IMA_.*/ } keys %{"DBI::"};
warn "@ima_n";
my %ima_n2v = map  { m/^(IMA_.*)/ ? ($1 => &$_) : () } @ima_n;
warn Dumper \%ima_n2v;
my %ima_v2n = reverse %ima_n2v;

my @bit2hex_bitkeys = map { 1 << $_ } 0 .. 31;
my @bit2hex_bitvals =
    map { sprintf "%s", $ima_v2n{$_} || "" } @bit2hex_bitkeys;
my %bit2hex;
@bit2hex{@bit2hex_bitkeys} = @bit2hex_bitvals;
my @bit2hex_values = ("0x00000000", @bit2hex_bitvals);

#warn Dumper \%DBI::DBI_methods;
for (0 .. 31) {
    my $bit       = 1 << $_;
    my @ima_flags = map { ($bit & $_) ? $bit2hex{$_} : () } @bit2hex_bitkeys;
    printf "%20s => %04x\n", "@ima_flags", $bit;
    }

while (my ($class, $meths) = each %DBI::DBI_methods) {

    for my $method (sort keys %$meths) {
	my $info     = $meths->{$method};
	my $fullmeth = "DBI::${class}::$method";

	my $proto = $info->{U}[2];
	unless (defined $proto) {
	    $proto = '$' x ($info->{U}[0] || 0);
	    $proto .= ";" . ('$' x $info->{U}[1]) if $info->{U}[1];
	    }

	my $O         = $info->{O} || 0;
	my @ima_flags = map { ($O & $_) ? $bit2hex{$_} : () } @bit2hex_bitkeys;

	printf "\$h->%s (%s)  %s # 0x%04x\n", $fullmeth, $proto, "@ima_flags", $O;
	}
    }
