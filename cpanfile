requires   "Module::Load"             => "0.22";
requires   "XSLoader";

recommends "Encode"                   => "3.24";

suggests   "Clone"                    => "0.50";
suggests   "DB_File";
suggests   "MLDBM";
suggests   "Module::Load"             => "0.36";
suggests   "Net::Daemon"              => "0.52";
suggests   "Params::Util"             => "1.102";
suggests   "RPC::PlClient"            => "0.2020";
suggests   "RPC::PlServer"            => "0.2020";
suggests   "SQL::Statement"           => "1.414";

conflicts  "DBD::Amazon"              => "<= 0.10";
conflicts  "DBD::AnyData"             => "<= 0.110";
conflicts  "DBD::CSV"                 => "<= 0.36";
conflicts  "DBD::Google"              => "<= 0.51";
conflicts  "DBD::PO"                  => "<= 2.10";
conflicts  "DBD::RAM"                 => "<= 0.072";
conflicts  "SQL::Statement"           => "<= 1.33";

on "configure" => sub {
    requires   "ExtUtils::MakeMaker"      => "6.48";

    recommends "ExtUtils::MakeMaker"      => "7.78";
    };

on "test" => sub {
    requires   "Test::More"               => "0.96";

    recommends "Test::More"               => "1.302225";
    };
