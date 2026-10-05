#!/pro/bin/perl

use 5.026001;
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
    Bundle::DBI:
        file:            lib/Bundle/DBI.pm
        version:         12.008696
    DBI:
        file:            DBI.pm
        version:         VERSION
    DBD::DBM:
        file:            lib/DBD/DBM.pm
        version:         0.08
    DBD::ExampleP:
        file:            lib/DBD/ExampleP.pm
        version:         12.014311
    DBD::File:
        file:            lib/DBD/File.pm
        version:         0.45
    DBD::Gofer:
        file:            lib/DBD/Gofer.pm
        version:         0.015327
    DBD::Gofer::Policy::Base:
        file:            lib/DBD/Gofer/Policy/Base.pm
        version:         0.010088
    DBD::Gofer::Policy::classic:
        file:            lib/DBD/Gofer/Policy/classic.pm
        version:         0.010088
    DBD::Gofer::Policy::pedantic:
        file:            lib/DBD/Gofer/Policy/pedantic.pm
        version:         0.010088
    DBD::Gofer::Policy::rush:
        file:            lib/DBD/Gofer/Policy/rush.pm
        version:         0.010088
    DBD::Gofer::Transport::Base:
        file:            lib/DBD/Gofer/Transport/Base.pm
        version:         0.014121
    DBD::Gofer::Transport::corostream:
        file:            lib/DBD/Gofer/Transport/corostream.pm
        version:         2.165300
    DBD::Gofer::Transport::null:
        file:            lib/DBD/Gofer/Transport/null.pm
        version:         0.010088
    DBD::Gofer::Transport::pipeone:
        file:            lib/DBD/Gofer/Transport/pipeone.pm
        version:         0.010088
    DBD::Gofer::Transport::stream:
        file:            lib/DBD/Gofer/Transport/stream.pm
        version:         0.014599
    DBD::Mem:
        file:            lib/DBD/Mem.pm
        version:         0.001
    DBD::NullP:
        file:            lib/DBD/NullP.pm
        version:         12.014715
    DBD::Proxy:
        file:            lib/DBD/Proxy.pm
        version:         0.2004
    DBD::Sponge:
        file:            lib/DBD/Sponge.pm
        version:         12.010003
    DBI::Const::GetInfo::ANSI:
        file:            lib/DBI/Const/GetInfo/ANSI.pm
        version:         2.008697
    DBI::Const::GetInfo::ODBC:
        file:            lib/DBI/Const/GetInfo/ODBC.pm
        version:         2.011374
    DBI::Const::GetInfoReturn:
        file:            lib/DBI/Const/GetInfoReturn.pm
        version:         2.008697
    DBI::Const::GetInfoType:
        file:            lib/DBI/Const/GetInfoType.pm
        version:         2.008697
    DBI::DBD:
        file:            lib/DBI/DBD.pm
        version:         12.015129
    DBI::DBD::Metadata:
        file:            lib/DBI/DBD/Metadata.pm
        version:         2.014214
    DBI::DBD::SqlEngine:
        file:            lib/DBI/DBD/SqlEngine.pm
        version:         0.06
    DBI::Gofer::Execute:
        file:            lib/DBI/Gofer/Execute.pm
        version:         0.014283
    DBI::Gofer::Request:
        file:            lib/DBI/Gofer/Request.pm
        version:         0.012537
    DBI::Gofer::Response:
        file:            lib/DBI/Gofer/Response.pm
        version:         0.011566
    DBI::Gofer::Serializer::Base:
        file:            lib/DBI/Gofer/Serializer/Base.pm
        version:         0.009950
    DBI::Gofer::Serializer::DataDumper:
        file:            lib/DBI/Gofer/Serializer/DataDumper.pm
        version:         0.009950
    DBI::Gofer::Serializer::Storable:
        file:            lib/DBI/Gofer/Serializer/Storable.pm
        version:         0.015586
    DBI::Gofer::Transport::Base:
        file:            lib/DBI/Gofer/Transport/Base.pm
        version:         0.012537
    DBI::Gofer::Transport::pipeone:
        file:            lib/DBI/Gofer/Transport/pipeone.pm
        version:         0.012537
    DBI::Gofer::Transport::stream:
        file:            lib/DBI/Gofer/Transport/stream.pm
        version:         0.012537
    DBI::Profile:
        file:            lib/DBI/Profile.pm
        version:         2.015065
    DBI::ProfileData:
        file:            lib/DBI/ProfileData.pm
        version:         2.010008
    DBI::ProfileDumper:
        file:            lib/DBI/ProfileDumper.pm
        version:         2.015325
    DBI::ProfileDumper::Apache:
        file:            lib/DBI/ProfileDumper/Apache.pm
        version:         2.014121
    DBI::ProfileSubs:
        file:            lib/DBI/ProfileSubs.pm
        version:         0.009396
    DBI::ProxyServer:
        file:            lib/DBI/ProxyServer.pm
        version:         0.3005
    DBI::PurePerl:
        file:            lib/DBI/PurePerl.pm
        version:         2.014286
    DBI::SQL::Nano:
        file:            lib/DBI/SQL/Nano.pm
        version:         1.015544
    DBI::Util::CacheMemory:
        file:            lib/DBI/Util/CacheMemory.pm
        version:         0.010315
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
    DBD::Amazon:         '<= 0.10'
    DBD::AnyData:        '<= 0.110'
    DBD::CSV:            '<= 0.36'
    DBD::Google:         '<= 0.51'
    DBD::PO:             '<= 2.10'
    DBD::RAM:            '<= 0.072'
    SQL::Statement:      '<= 1.33'
test_recommends:
    Test::More:          1.302225
resources:
    license:             http://dev.perl.org/licenses/
    repository:          https://github.com/perl5-dbi/dbi
    bugtracker:          https://github.com/perl5-dbi/dbi/issues
    IRC:                 irc://irc.perl.org/#dbi
meta-spec:
    version:             1.4
    url:                 http://module-build.sourceforge.net/META-spec-v1.4.html
