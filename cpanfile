requires   "XSLoader";

recommends "Encode"                   => "3.21";

suggests   "Clone"                    => "0.47";
suggests   "DB_File"                  => "0";
suggests   "MLDBM"                    => "0";
suggests   "Net::Daemon"              => "0";
suggests   "RPC::PlServer"            => "0.2020";
suggests   "SQL::Statement"           => "1.414";

conflicts  "DBD::Amazon"              => "0.10";
conflicts  "DBD::AnyData"             => "0.110";
conflicts  "DBD::CSV"                 => "0.36";
conflicts  "DBD::Google"              => "0.51";
conflicts  "DBD::PO"                  => "2.10";
conflicts  "DBD::RAM"                 => "0.072";
conflicts  "SQL::Statement"           => "1.33";

on "configure" => sub {
    requires   "ExtUtils::MakeMaker"  => "6.48";

    recommends "ExtUtils::MakeMaker"  => "7.70";
    };

on "build" => sub {
    requires   "Config";
    requires   "ExtUtils::MakeMaker"  => "6.48";

    recommends "ExtUtils::MakeMaker"  => "7.70";
    };

on "test" => sub {
    requires   "Test::More"           => "0.90";    # For done_testing()

    recommends "Test::More"           => "1.302199";
    };
