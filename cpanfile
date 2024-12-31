requires   "XSLoader";

recommends "Encode"                   => "3.21";

suggests   "Clone"                    => "0.47";
suggests   "DB_File";
suggests   "MLDBM";
suggests   "Net::Daemon";
suggests   "RPC::PlServer"            => "0.2020";
suggests   "SQL::Statement"           => "1.414";

on "configure" => sub {
    requires   "ExtUtils::MakeMaker"      => "6.48";

    recommends "ExtUtils::MakeMaker"      => "7.70";
    };

on "test" => sub {
    requires   "Test::More"               => "0.90";

    recommends "Test::More"               => "1.302207";
    };
