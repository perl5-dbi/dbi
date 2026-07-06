requires   "XSLoader";
requires   "Module::Load"             => "0.22";

recommends "Encode"                   => "3.24";

suggests   "Clone"                    => "0.50";
suggests   "DB_File";
suggests   "MLDBM";
suggests   "Net::Daemon"              => "0.52";
suggests   "RPC::PlServer"            => "0.2020";
suggests   "SQL::Statement"           => "1.414";

on "configure" => sub {
    requires   "ExtUtils::MakeMaker"  => "6.48";

    recommends "ExtUtils::MakeMaker"  => "7.78";
    };

on "test" => sub {
    requires   "Test::More"           => "0.96";

    recommends "Test::More"           => "1.302222";
    };
