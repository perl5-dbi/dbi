#!perl -w

use strict;

$|=1;
$^W=1;

use vars qw($tests);
my $calls = 0;


# =================================================
# Example code for sub classing the DBI.
#
# Note that the extra ::db and ::st classes must be set up
# as sub classes of the corresponding DBI classes.
#
# This whole mechanism is new and experimental - it may change!

package MyDBI;
@MyDBI::ISA = qw(DBI);

package MyDBI::dr;
@MyDBI::dr::ISA = qw(DBI::dr);

sub connect {
    my ($drh, $dsn, $user, $pass, $attr) = @_;
    my $dbh = $drh->SUPER::connect($dsn, $user, $pass, $attr);
    delete $attr->{CompatMode};	# to test clone
    return $dbh;
}

package MyDBI::db;
@MyDBI::db::ISA = qw(DBI::db);

sub prepare {
    my($dbh, @args) = @_;
    ++$calls;
    my $sth = $dbh->SUPER::prepare(@args);
    return $sth;
}


package MyDBI::st;
@MyDBI::st::ISA = qw(DBI::st);

sub fetch {
    my($sth, @args) = @_;
    ++$calls;
    my $row = $sth->SUPER::fetch(@args);
    if ($row) {
	# modify fetched data as an example
	$row->[1] = lc($row->[1]);

	# also demonstrate calling set_err()
	return $sth->set_err(1,"Don't be so negative",undef,"fetch")
		if $row->[0] < 0;
	# ... and providing alternate results
	# (although typically would trap and hide and error from SUPER::fetch)
	return $sth->set_err(2,"Don't exagerate",undef, undef, [ 42,"zz",0 ])
		if $row->[0] > 42;
    }
    return $row;
}


# =================================================
package main;

print "1..$tests\n";
my $t;

sub ok ($$$) {
    my($n, $got, $want) = @_;
    ++$t;
    die "sequence error, expected $n but actually $t"
	if $n and $n != $t;
    my $line = (caller)[2];
    return print "ok $t at $line\n"
	if(	( defined($got) && defined($want) && $got eq $want)
	||	(!defined($got) && !defined($want)) );
    warn "Test $n: wanted '$want', got '$got'\n";
    print "not ok $t at $line\n";
}


# =================================================
package main;

use DBI;

my $tmp;

#DBI->trace(2);
my $dbh = MyDBI->connect("dbi:Sponge:foo","","", {
	PrintError => 0,
	RaiseError => 1,
	CompatMode => 1, # just for clone test
});
ok(0, ref $dbh, 'MyDBI::db');
ok(0, $dbh->{CompatMode}, 1);
undef $dbh;

$dbh = DBI->connect("dbi:Sponge:foo","","", {
	PrintError => 0,
	RaiseError => 1,
	RootClass => "MyDBI",
	CompatMode => 1, # just for clone test
});
ok(0, ref $dbh, 'MyDBI::db');
ok(0, $dbh->{CompatMode}, 1);

#$dbh->trace(5);
my $sth = $dbh->prepare("foo",
    # data for DBD::Sponge to return via fetch
    { rows => [
	[ 40, "AAA", 9 ],
	[ 41, "BB",  8 ],
	[ -1, "C",   7 ],
	[ 49, "DD",  6 ]
	],
    }
);

ok(0, $calls, 1);
ok(0, ref $sth, 'MyDBI::st');

my $row = $sth->fetch;
ok(0, $calls, 2);
ok(0, $row->[1], "aaa");

$row = $sth->fetch;
ok(0, $calls, 3);
ok(0, $row->[1], "bb");

ok(0, $DBI::err, undef);
$row = eval { $sth->fetch };
ok(0, !defined $row, 1);
ok(0, substr($@,0,50), "DBD::Sponge::st fetch failed: Don't be so negative");

#$sth->trace(5);
#$sth->{PrintError} = 1;
$sth->{RaiseError} = 0;
$row = eval { $sth->fetch };
ok(0, ref $row, 'ARRAY');
ok(0, $row->[0], 42);
ok(0, $DBI::err, 2);
ok(0, $DBI::errstr =~ /Don't exagerate/, 1);
ok(0, $@ =~ /Don't be so negative/, $@);


print "clone A\n";
my $dbh2 = $dbh->clone;
ok(0, $dbh2 != $dbh, 1);
ok(0, ref $dbh2, 'MyDBI::db');
ok(0, $dbh2->{CompatMode}, 1);

print "clone B\n";
my $dbh3 = $dbh->clone;
ok(0, $dbh3 != $dbh, 1);
ok(0, $dbh3 != $dbh2, 1);
ok(0, ref $dbh3, 'MyDBI::db');
ok(0, $dbh3->{CompatMode}, 1);

print "installed method\n";
$tmp = $dbh->sponge_test_installed_method('foo','bar');
ok(0, ref $tmp, "ARRAY");
ok(0, join(':',@$tmp), "foo:bar");
$tmp = eval { $dbh->sponge_test_installed_method() };
ok(0, !$tmp, 1);
ok(0, $dbh->err, 42);
ok(0, $dbh->errstr, "not enough parameters");


$dbh = eval { DBI->connect("dbi:Sponge:foo","","", {
	RootClass => 'nonesuch1', PrintError => 0, RaiseError => 0, });
};
ok(0, substr($@,0,25), "Can't locate nonesuch1.pm");

$dbh = eval { nonesuch2->connect("dbi:Sponge:foo","","", {
	PrintError => 0, RaiseError => 0, });
};
ok(0, substr($@,0,36), q{Can't locate object method "connect"});


BEGIN { $tests = 32 }
