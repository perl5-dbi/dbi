package DBI;

BEGIN { $ENV{DBI_PUREPERL} = 2 }
use DBI;

no strict qw(subs refs); # build name and code to value mappings introspectively
my @ima_n   = grep { /^IMA_.*/ } keys %{"DBI::"};
warn "@ima_n";
my %ima_n2v = map { /^(IMA_.*)/ ? ($1=>&$_) : () } @ima_n;
my %ima_v2n = reverse %ima_n2v;    
my @ima_a   = map { $ima_v2a{1<<$_} || "b".($_+1) } 0..31;

my @bit2hex_bitkeys = map { 1<<$_ } 0..31;
my @bit2hex_bitvals = map { sprintf("%s", $ima_v2n{$_}||'') } @bit2hex_bitkeys;
my %bit2hex; @bit2hex{ @bit2hex_bitkeys } = @bit2hex_bitvals;
my @bit2hex_values = ("0x00000000", @bit2hex_bitvals);

use Data::Dumper;
warn Dumper \%DBI::DBI_methods;

while ( my ($class, $meths) = each %DBI::DBI_methods ) {

    for my $method (sort keys %$meths) {
        my $info = $meths->{$method};
        my $fullmeth = "DBI::${class}::$method"; 

        my $proto = $info->{U}[2];
        unless (defined $proto) {
            $proto = '$' x ($info->{U}[0]||0);
            $proto .= ";" . ('$' x $info->{U}[1]) if $info->{U}[1];
        }

        my $O = $info->{O}||0;
        my @ima_flags = map { ($O & $_) ? $bit2hex{$_} : () } @bit2hex_bitkeys;

        print "\$h->$fullmeth($proto)  @ima_flags\n";
    }
}   

