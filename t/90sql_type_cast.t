# $Id$
# Test DBI::sql_type_cast
use strict;
#use warnings; this script generate warnings deliberately as part of the test
use Test::More;
use DBI qw(:sql_types :utils);
use Config;

my $jx = eval {require JSON::XS;};
my $dp = eval {require Data::Peek;};
my $pp = $DBI::PurePerl && $DBI::PurePerl; # doubled to avoid typo warning

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
    ['undef', undef, SQL_INTEGER, SV_IS_UNDEF, -1, q{[null]}],
    ['invalid sql type', '99', 123456789, 0, INVALID_TYPE, q{["99"]}],
    ['non numeric cast to int', 'aa', SQL_INTEGER, 0, NO_CAST_NO_STRICT,
     q{["aa"]}],
    ['non numeric cast to int (strict)', 'aa', SQL_INTEGER,
     DBIstcf_STRICT, NO_CAST_STRICT, q{["aa"]}],
    ['small int cast to int', "99", SQL_INTEGER, 0, CAST_OK, q{["99"]}],
    ['2 byte max signed int cast to int', "32767", SQL_INTEGER, 0,
     CAST_OK, q{["32767"]}],
    ['2 byte max unsigned int cast to int', "65535",
     SQL_INTEGER, 0, CAST_OK, q{["65535"]}],
    ['4 byte max signed int cast to int', "2147483647",
     SQL_INTEGER, 0, CAST_OK, q{["2147483647"]}],
    ['4 byte max unsigned int cast to int', "4294967295",
     SQL_INTEGER, 0, CAST_OK, q{["4294967295"]}],
    ['small int cast to int (discard)',
     '99', SQL_INTEGER, DBIstcf_DISCARD_STRING, CAST_OK, q{[99]}],

    ['non numeric cast to numeric', 'aa', SQL_NUMERIC,
     0, NO_CAST_NO_STRICT, q{["aa"]}],
    ['non numeric cast to numeric (strict)', 'aa', SQL_NUMERIC,
     DBIstcf_STRICT, NO_CAST_STRICT, q{["aa"]}],
   );

if (!$pp) {
    # some tests cannot be performed with PurePerl as numbers don't
    # overflow in the same way as XS.
    push @tests,
        (
            ['very large int cast to int',
             '99999999999999999999', SQL_INTEGER, 0, NO_CAST_NO_STRICT,
             q{["99999999999999999999"]}],
            ['very large int cast to int (strict)',
             '99999999999999999999', SQL_INTEGER, DBIstcf_STRICT,
             NO_CAST_STRICT, q{["99999999999999999999"]}],
            ['float cast to int', '99.99', SQL_INTEGER, 0,
             NO_CAST_NO_STRICT, q{["99.99"]}],
            ['float cast to int (strict)', '99.99', SQL_INTEGER, DBIstcf_STRICT,
             NO_CAST_STRICT, q{["99.99"]}],
            ['float cast to double', '99.99', SQL_DOUBLE, 0, CAST_OK,
             q{["99.99"]}]
           );
    if ($Config{ivsize} == 4) {
        push @tests,
            ['4 byte max unsigned int cast to int (ivsize=4)', "4294967296",
             SQL_INTEGER, 0, NO_CAST_NO_STRICT, q{["4294967296"]}];
    } elsif ($Config{ivsize} >= 8) {
        push @tests,
            ['4 byte max unsigned int cast to int (ivsize>8)', "4294967296",
             SQL_INTEGER, 0, CAST_OK, q{["4294967296"]}];
    }
}

if ($] >= 5.010001) {
   # Some numeric tests fail the return value test on Perls before 5.10.1
   # because sv_2nv leaves NOK set - changed in 5.10.1 probably via the
   # following change:
   # The public IV and NV flags are now not set if the string
   # value has trailing "garbage". This behaviour is consistent with not
   # setting the public IV or NV flags if the value is out of range for the
   # type.
   push @tests, (
    ['non numeric cast to double', 'aabb', SQL_DOUBLE, 0,
     NO_CAST_NO_STRICT, q{["aabb"]}],
    ['non numeric cast to double (strict)', 'aabb', SQL_DOUBLE,
     DBIstcf_STRICT, NO_CAST_STRICT, q{["aabb"]}]
   );
}

my $tests = @tests;
$tests *= 2 if $jx;
foreach (@tests) {
    $tests++ if ($dp) && ($_->[3] & DBIstcf_DISCARD_STRING);
    $tests++ if ($dp) && ($_->[2] == SQL_DOUBLE);
}

plan tests => $tests;

foreach my $test(@tests) {
    my $val = $test->[1];
    #diag(join(",", map {neat($_)} Data::Peek::DDual($val)));
    my $result;
    {
        no warnings;   # lexical but also affects XS sub
        local $^W = 0; # needed for PurePerl tests
        $result = sql_type_cast($val, $test->[2], $test->[3]);
    }
    is($result, $test->[4], "result, $test->[0]");
    if ($jx) {

      SKIP: {
            skip 'DiscardString not supported in PurePerl', 1
                if $pp && ($test->[3] & DBIstcf_DISCARD_STRING);

            my $json = JSON::XS->new->encode([$val]);
            #diag(neat($val), ",", $json);
            # This test is about quotation of the value, not about the
            # style/formatting of JSON. Strip all leading/trailing
            # whitespace that is not part of the test, treating '[99]'
            # identical to ' [ 99 ] ' or '[99   ]'
            $json =~ s{^\s*\[\s*(.*?)\s*\]\s*$}{[$1]};
            is($json, $test->[5], "json $test->[0]");
        };
    }

    my ($pv, $iv, $nv, $rv, $hm);
    ($pv, $iv, $nv, $rv, $hm) = Data::Peek::DDual($val) if $dp;

    if ($dp && ($test->[3] & DBIstcf_DISCARD_STRING)) {
        #diag("D::P ",neat($pv), ",", neat($iv), ",", neat($nv),
        #     ",", neat($rv));
      SKIP: {
            skip 'DiscardString not supported in PurePerl', 1 if $pp;

            ok(!defined($pv), "discard works, $test->[0]") if $dp;
        };
    }
    if (($test->[2] == SQL_DOUBLE) && ($dp)) {
        #diag("D::P ", neat($pv), ",", neat($iv), ",", neat($nv),
        #     ",", neat($rv));
        if ($test->[4] == CAST_OK) {
            ok(defined($nv), "nv defined $test->[0]");
        } else {
            ok(!defined($nv) || !$nv, "nv not defined $test->[0]");
        }
    }
}

1;
