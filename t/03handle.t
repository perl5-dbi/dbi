#!perl -w

use strict;
use Test::More;
use Data::Dumper;

# handle tests

BEGIN { plan tests => 52 }

use DBI;

my $driver = "ExampleP";

do {
    my $dbh = DBI->connect("dbi:$driver:", '', '');

    my $sql = "select name from ?";
    my $sth1 = $dbh->prepare_cached($sql);
    ok($sth1->execute("."));
    my $ck = $dbh->{CachedKids};
    ok(keys %$ck == 1);

    my $warn = 0;
    local $SIG{__WARN__} = sub { ++$warn if $_[0] =~ /still active/ };
    my $sth2 = $dbh->prepare_cached($sql);
    ok($sth1 == $sth2);
    ok($warn == 1);
    ok(!$sth1->{Active});

       $sth2 = $dbh->prepare_cached($sql, { foo => 1 });
    ok($sth1 != $sth2);
    ok(keys %$ck == 2);

    ok($sth1->execute("."));
    ok($sth1->{Active});
       $sth2 = $dbh->prepare_cached($sql, undef, 3);
    ok($sth1 != $sth2);
    ok($sth1->{Active}); # active but no longer cached
    $sth1->finish;

    ok($sth2->execute("."));
    ok($sth2->{Active});
       $sth1 = $dbh->prepare_cached($sql, undef, 1);
    ok($sth1 == $sth2);
    ok(!$sth2->{Active});

    ok($warn == 1);
    $dbh->disconnect;
};

my $drh = DBI->install_driver($driver);
ok($drh);
is($drh->{Kids}, 0);


# --- handle reference leak tests

sub work {
    my (%args) = @_;
    my $dbh = DBI->connect("dbi:$driver:", '', '');
    ok(ref $dbh->{Driver}) if $args{Driver};
    my $sth = $dbh->prepare_cached("select name from ?");
    ok(ref $sth->{Database}) if $args{Database};
    $dbh->disconnect;
    # both handles should be freed here
}

foreach my $args (
	{},
	{ Driver   => 1 },
	{ Database => 1 },
	{ Driver   => 1, Database => 1 },
) {
    print "ref leak using @{[ %$args ]}\n";
    work( %$args );
    is($drh->{Kids}, 0);
}

# --- handle take_imp_data test

print "take_imp_data\n";
unless ($DBI::PurePerl) {

my $dbh = DBI->connect("dbi:$driver:", '', '');

#DBI->trace(9);
my $imp_data = $dbh->take_imp_data;
ok($imp_data);
# generally length($imp_data) = 112 for 32bit, 116 for 64 bit
# (as of DBI 1.37) but it can differ on some platforms
# depending on structure packing by the compiler
# so we just test that it's something reasonable:
ok(length($imp_data) >= 80);
#print Dumper($imp_data);

{
my ($tmp, $warn);
local $SIG{__WARN__} = sub { ++$warn if $_[0] =~ /after take_imp_data/ };
is($tmp=$dbh->{Driver}, undef);
is($tmp=$dbh->{TraceLevel}, undef);
is($dbh->disconnect, undef);
is($dbh->quote(42), undef);
is($warn, 4);
}

print "use dbi_imp_data\n";
my $dbh2 = DBI->connect("dbi:$driver:", '', '', { dbi_imp_data => $imp_data });
ok($dbh2);
# need a way to test dbi_imp_data has been used

}
else {
    ok(1) for (1..8);
}

print "NullP statement handle attributes without execute\n";
my $dbh = DBI->connect("dbi:NullP:", '', '');
my $sth = $dbh->prepare("foo bar");
is $sth->{NUM_OF_PARAMS}, 0;
is $sth->{NUM_OF_FIELDS}, undef;
is $sth->{Statement}, "foo bar";
is $sth->{NAME}, undef;
is $sth->{TYPE}, undef;
is $sth->{SCALE}, undef;
is $sth->{PRECISION}, undef;
is $sth->{NULLABLE}, undef;
is $sth->{RowsInCache}, undef;
is $sth->{ParamValues}, undef;
# derived NAME attributes
is $sth->{NAME_uc}, undef;
is $sth->{NAME_lc}, undef;
is $sth->{NAME_hash}, undef;
is $sth->{NAME_uc_hash}, undef;
is $sth->{NAME_lc_hash}, undef;

ok  ref($dbh)->can("prepare");
ok !ref($dbh)->can("nonesuch");
ok  ref($sth)->can("execute");

# I don't know why this warning has the "(perhaps ...)" suffix, it shouldn't:
# Can't locate object method "nonesuch" via package "DBI::db" (perhaps you forgot to load "DBI::db"?)
eval { ref($dbh)->nonesuch; };

exit 0;
