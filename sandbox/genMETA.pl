#!/pro/bin/perl

use 5.018002;
use warnings;

use Getopt::Long qw(:config bundling nopermute);
my $check = 0;
my $opt_v = 0;
GetOptions (
    "c|check"		=> \$check,
    "v|verbose:1"	=> \$opt_v,
    ) or die "usage: $0 [--check]\n";

use lib "sandbox";
use genMETA;
my $meta = genMETA->new (
    from    => "DBI.pm",
    verbose => $opt_v,
    );

$meta->from_data (<DATA>);
$meta->gen_cpanfile ();

if ($check) {
    $meta->check_encoding ();
    $meta->check_required ();
    $meta->check_minimum ();
    $meta->done_testing ();
    }
elsif ($opt_v) {
    $meta->print_yaml ();
    }
else {
    $meta->fix_meta ();
    }

__END__
--- #YAML:1.0
name:                    DBI
version:                 VERSION
abstract:                Database independent interface for Perl
license:                 perl
author:
    - DBI team (dbi-users@perl.org)
generated_by:            Author
distribution_type:       module
provides:
    DBI:
        file:            DBI.pm
        version:         VERSION
requires:
    perl:                5.012000
    Module::Load:        0.22
    XSLoader:            0
configure_requires:
    ExtUtils::MakeMaker: 6.48
configure_recommends:
    ExtUtils::MakeMaker: 7.78
build_requires:
    perl:                5.008001
test_requires:
    Test::More:          0.96
recommends:
    Encode:              3.24
suggests:
    Clone:               0.50
    DB_File:             0
    MLDBM:               0
    Module::Load:        0.36
    Net::Daemon:         0.52
    Params::Util:        1.102
    RPC::PlClient:       0.2020
    RPC::PlServer:       0.2020
    SQL::Statement:      1.414
conflicts:
    DBD::Amazon:         0.10
    DBD::AnyData:        0.110
    DBD::CSV:            0.36
    DBD::Google:         0.51
    DBD::PO:             2.10
    DBD::RAM:            0.072
    SQL::Statement:      1.33
test_recommends:
    Test::More:          1.302224
resources:
    license:             http://dev.perl.org/licenses/
    repository:          https://github.com/perl5-dbi/dbi
    bugtracker:          https://github.com/perl5-dbi/dbi/issues
    IRC:                 irc://irc.perl.org/#dbi
meta-spec:
    version:             1.4
    url:                 http://module-build.sourceforge.net/META-spec-v1.4.html
