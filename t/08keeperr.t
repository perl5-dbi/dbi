#!../perl -w
 
$|=1;
$^W=1;
 
my $tests;
print "1..$tests\n";
 
sub ok ($$;$) {
    my($n, $got, $want) = @_;
    ++$t;
    die "sequence error, expected $n but actually $t"
        if $n and $n != $t;
    my $line = (caller)[2];
    return print "ok $t at line $line\n" if @_<3 && $got;
    return print "ok $t at line $line\n" if $got eq $want;
    print "not ok $t\n";
    warn "# failed test $t at line $line: wanted '$want', got '$got'\n";
}


package My::DBI;
use base 'DBI';

package My::DBI::db;
use base 'DBI::db';

package My::DBI::st;
use base 'DBI::st';

sub execute {
  my $sth = shift;
  # we localize and attribute here to check that the correpoding STORE
  # at scope exit doesn't clear any recorded error
  local $sth->{CompatMode} = 0;
  my $rv = $sth->SUPER::execute(@_);
  return $rv;
}

package Test;

use strict;
use base 'My::DBI';

use DBI;

my @con_info = ('dbi:ExampleP:.', undef, undef, { PrintError=>0, RaiseError=>1 });

sub test_select {
  my $dbh = shift;
  eval { $dbh->selectrow_arrayref('select * from foo') };
  $dbh->disconnect;
  return $@;
}

my $err1 = test_select( My::DBI->connect(@con_info) );
::ok(0, $err1 =~ /^DBD::(ExampleP|Multiplex)::db selectrow_arrayref failed: opendir/) or print "got: $err1\n";

my $err2 = test_select( DBI->connect(@con_info) );
::ok(0, $err2 =~ /^DBD::(ExampleP|Multiplex)::db selectrow_arrayref failed: opendir/) or print "got: $err2\n";

package main;

print "test HandleSetErr\n";

my $dbh = DBI->connect(@con_info);
$dbh->{RaiseError} = 1;
$dbh->{PrintError} = 1;

my $warn = 0;
my @handlewarn = (0,0,0);
$SIG{__WARN__} = sub {
    if ($_[0] =~ /^DBD::ExampleP::/) {
	++$warn;
	print "warn called: @_\n";
	return;
    }
    warn @_;
};
#$dbh->trace(2);
$dbh->{HandleSetErr} = sub {
    my ($h, $err, $errstr, $state) = @_;
    return 0 unless defined $err;
    ++$handlewarn[ $err ? 2 : length($err) ]; # count [info, warn, err] calls
    return 1
	if $state && $state eq "return";   # for tests
    ($_[1], $_[2], $_[3]) = (99, "errstr99", "OV123")
	if $state && $state eq "override"; # for tests
    return 0 if $err; # be transparent for errors
    local $^W;
    print "HandleSetErr called: h=$h, err=$err, errstr=$errstr, state=$state\n";
    return 0;
};
ok(0, !defined $DBI::err, 1);

$dbh->set_err("", "(got info)");
ok(0, defined $DBI::err, 1);	# true
ok(0, $DBI::err, "");
ok(0, $DBI::errstr, "(got info)");
ok(0, $dbh->errstr, "(got info)");
ok(0, $warn, 0);
ok(0, "@handlewarn", "1 0 0");

$dbh->set_err("0", "(got warn)", "AA001");
ok(0, defined $DBI::err, 1);
ok(0, $DBI::err, "0");
ok(0, $DBI::errstr, "(got info)\n(got warn)");
ok(0, $dbh->errstr, "(got info)\n(got warn)");
ok(0, $warn, 1);
ok(0, "@handlewarn", "1 1 0");
ok(0, $DBI::state, "AA001");

$dbh->set_err("", "(got more info)");
ok(0,  defined $DBI::err);
ok(0, $DBI::err, "0");	# not "", ie it's still a warn
ok(0, $DBI::errstr, "(got info)\n(got warn)\n(got more info)");
ok(0, $warn, 2);
ok(0, "@handlewarn", "2 1 0");
ok(0, $DBI::state, "AA001");

$dbh->{RaiseError} = 0;
$dbh->{PrintError} = 0;

$dbh->set_err("42", "(got error)", "AA002");
ok(0, $DBI::err, 42);
ok(0, $dbh->errstr, "(got info)\n(got warn)\n(got more info) [state was AA001 now AA002]\n(got error)");
ok(0, $warn, 2);
ok(0, "@handlewarn", "2 1 1");
ok(0, $DBI::state, "AA002");

$dbh->set_err("", "(got info)");
ok(0, $DBI::err, 42);
ok(0, $dbh->errstr, "(got info)\n(got warn)\n(got more info) [state was AA001 now AA002]\n(got error)\n(got info)");
ok(0, $warn, 2);
ok(0, "@handlewarn", "3 1 1");

$dbh->set_err("0", "(got warn)");
ok(0, $DBI::err, 42);
ok(0, $dbh->errstr, "(got info)\n(got warn)\n(got more info) [state was AA001 now AA002]\n(got error)\n(got info)\n(got warn)");
ok(0, $warn, 2);
ok(0, "@handlewarn", "3 2 1");

$dbh->set_err("4200", "(got new error)", "AA003");
ok(0, $DBI::err, 4200);
ok(0, $dbh->errstr, "(got info)\n(got warn)\n(got more info) [state was AA001 now AA002]\n(got error)\n(got info)\n(got warn) [err was 42 now 4200] [state was AA002 now AA003]\n(got new error)");
ok(0, $warn, 2);
ok(0, "@handlewarn", "3 2 2");

$dbh->set_err(undef, "foo", "bar"); # clear error
ok(0, !defined $dbh->err);
ok(0, !defined $dbh->errstr);
ok(0, $dbh->state, "");

$warn = 0;
@handlewarn = (0,0,0);
my @ret;
@ret = $dbh->set_err(1, "foo");
ok(0, @ret == 1);
ok(0, !defined $ret[0]);
$dbh->set_err(2, "bar");
$dbh->set_err(3, "baz");
$dbh->set_err(0, "warn");
ok(0, $dbh->errstr, "foo [err was 1 now 2]\nbar [err was 2 now 3]\nbaz\nwarn");
ok(0, $warn, 0);
ok(0, "@handlewarn", "0 1 3");

$dbh->set_err(undef, undef, undef); # clear error
@ret = $dbh->set_err(1, "foo", "AA123", "method");
ok(0, @ret == 1 && !defined $ret[0]);
@ret = $dbh->set_err(1, "foo", "AA123", "method", "42");
ok(0, @ret == 1 && $ret[0] eq "42");
@ret = $dbh->set_err(1, "foo", "return");
ok(0, @ret == 0);

$dbh->set_err(undef, undef, undef); # clear error
@ret = $dbh->set_err("", "info", "override");
ok(0, @ret == 1 && !defined $ret[0]);
ok(0, $dbh->err,    99);
ok(0, $dbh->errstr, "errstr99");
ok(0, $dbh->state,  "OV123");

BEGIN { $tests = 54 }
