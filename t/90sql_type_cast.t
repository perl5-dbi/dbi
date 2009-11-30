# $Id$
# Test DBI::sql_type_cast
use strict;
#use warnings; this script generate warnings deliberately as part of the test
use Test::More;
use DBI;
use Config;

my $jx = eval {require JSON::XS;};
my $dp = eval {require Data::Peek;};

# NOTE: would have liked to use DBI::neat to test the cast value is what
# we expect but unfortunately neat uses SvNIOK(sv) so anything that looks
# like a number is printed as a number without quotes even if it has
# a pv.

use constant INVALID_TYPE => -2;
use constant SV_IS_UNDEF => -1;
use constant NO_CAST_STRICT => 0;
use constant NO_CAST_NO_STRICT => 1;
use constant CAST_OK => 2;

my @tests = (
    ['undef', undef, DBI::SQL_INTEGER, SV_IS_UNDEF, -1, q{[null]}],
    ['invalid sql type', '99', 123456789, 0, INVALID_TYPE, q{["99"]}],
    ['non numeric cast to int', 'aa', DBI::SQL_INTEGER, 0, NO_CAST_NO_STRICT,
     q{["aa"]}],
    ['non numeric cast to int (strict)', 'aa', DBI::SQL_INTEGER,
     DBI::DBIstcf_STRICT, NO_CAST_STRICT, q{["aa"]}],
    ['small int cast to int', "99", DBI::SQL_INTEGER, 0, CAST_OK, q{["99"]}],
    ['2 byte max signed int cast to int', "32767", DBI::SQL_INTEGER, 0,
     CAST_OK, q{["32767"]}],
    ['2 byte max unsigned int cast to int', "65535",
     DBI::SQL_INTEGER, 0, CAST_OK, q{["65535"]}],
    ['4 byte max signed int cast to int', "2147483647",
     DBI::SQL_INTEGER, 0, CAST_OK, q{["2147483647"]}],
    ['4 byte max unsigned int cast to int', "4294967295",
     DBI::SQL_INTEGER, 0, CAST_OK, q{["4294967295"]}],
    ['very large int cast to int',
     '99999999999999999999', DBI::SQL_INTEGER, 0, NO_CAST_NO_STRICT,
     q{["99999999999999999999"]}],
    ['very large int cast to int (strict)',
     '99999999999999999999', DBI::SQL_INTEGER, DBI::DBIstcf_STRICT,
     NO_CAST_STRICT, q{["99999999999999999999"]}],
    ['small int cast to int (discard)',
     '99', DBI::SQL_INTEGER, DBI::DBIstcf_DISCARD_STRING, CAST_OK, q{[99]}],

    ['float cast to int', '99.99', DBI::SQL_INTEGER, 0,
     NO_CAST_NO_STRICT, q{["99.99"]}],
    ['float cast to int', '99.99', DBI::SQL_INTEGER, DBI::DBIstcf_STRICT,
     NO_CAST_STRICT, q{["99.99"]}],
    ['float cast to double', '99.99', DBI::SQL_DOUBLE, 0, CAST_OK,
     q{["99.99"]}],
    ['non numeric cast to double', 'aabb', DBI::SQL_DOUBLE, 0,
     NO_CAST_NO_STRICT, q{["aabb"]}],
    ['non numeric cast to double (strict)', 'aabb', DBI::SQL_DOUBLE,
     DBI::DBIstcf_STRICT, NO_CAST_STRICT, q{["aabb"]}],

    ['non numeric cast to numeric', 'aa', DBI::SQL_NUMERIC,
     0, NO_CAST_NO_STRICT, q{["aa"]}],
    ['non numeric cast to numeric (strict)', 'aa', DBI::SQL_NUMERIC,
     DBI::DBIstcf_STRICT, NO_CAST_STRICT, q{["aa"]}],
   );

if ($Config{longsize} == 4) {
    push @tests,
        ['4 byte max unsigned int cast to int', "4294967296",
         DBI::SQL_INTEGER, 0, NO_CAST_NO_STRICT, q{["4294967296"]}];
} elsif ($Config{longsize} >= 8) {
    push @tests,
        ['4 byte max unsigned int cast to int', "4294967296",
         DBI::SQL_INTEGER, 0, CAST_OK, q{["4294967296"]}];
}

my $tests = @tests;
$tests *= 2 if $jx;
$tests++;                       # for use_ok
foreach (@tests) {
    $tests++ if ($dp) && ($_->[3] & DBI::DBIstcf_DISCARD_STRING);
    $tests++ if ($dp) && ($_->[2] == DBI::SQL_DOUBLE);
}

plan tests => $tests;

BEGIN {
    use_ok('DBI');
}

foreach my $test(@tests) {
    my $val = $test->[1];
    #diag(join(",", map {DBI::neat($_)} Data::Peek::DDual($val)));
    my $result;
    {
        no warnings;
        $result = DBI::sql_type_cast($val, $test->[2], $test->[3]);
    }
    is($result, $test->[4], "result, $test->[0]");
    if ($jx) {
        my $json = JSON::XS->new->encode([$val]);
        #diag(DBI::neat($val), ",", $json);
        is($json, $test->[5], "json $test->[0]");
    }
    
    my ($pv, $iv, $nv, $rv, $hm);
    ($pv, $iv, $nv, $rv, $hm) = Data::Peek::DDual($val) if $dp;

    if ($dp && ($test->[3] & DBI::DBIstcf_DISCARD_STRING)) {
        #diag("D::P ",DBI::neat($pv), ",", DBI::neat($iv), ",", DBI::neat($nv),
        #     ",", DBI::neat($rv));
        ok(!defined($pv), "discard works, $test->[0]") if $dp;
    }
    if (($test->[2] == DBI::SQL_DOUBLE) && ($dp)) {
        #diag("D::P ", DBI::neat($pv), ",", DBI::neat($iv), ",", DBI::neat($nv),
        #     ",", DBI::neat($rv));
        if ($test->[4] == CAST_OK) {
            ok(defined($nv), "nv defined $test->[0]");
        } else {
            ok(!defined($nv) || !$nv, "nv not defined $test->[0]");
        }
    }
}
