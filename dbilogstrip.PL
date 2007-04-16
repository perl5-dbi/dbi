# -*- perl -*-
my $file = $ARGV[0] || 'dbilogstrip';

my $script = <<'SCRIPT';
~startperl~

use strict;

while (<>) {
    # normalize hex addresses: 0xDEADHEAD => 0x
    s/ \b 0x [0-9a-f]+ /0x/gx;
    # normalize process id number
    s/ \b pid \W? \d+ /pidN/gx;

} continue {
    print or die "-p destination: $!\n";
}


SCRIPT

require Config;
my $config = {};
$config->{'startperl'} = $Config::Config{'startperl'};

$script =~ s/\~(\w+)\~/$config->{$1}/eg;
if (!(open(FILE, ">$file"))  ||
    !(print FILE $script)  ||
    !(close(FILE))) {
    die "Error while writing $file: $!\n";
}
chmod 0755, $file;
print "Extracted $file from ",__FILE__," with variable substitutions.\n";

