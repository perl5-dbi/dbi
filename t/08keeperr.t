#!../perl -w

use strict;
use Test::More tests => 63;
 
$|=1;
$^W=1;
 
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
::ok($err1 =~ /^DBD::(ExampleP|Multiplex)::db selectrow_arrayref failed: opendir/) or print "got: $err1\n";

my $err2 = test_select( DBI->connect(@con_info) );
::ok($err2 =~ /^DBD::(ExampleP|Multiplex)::db selectrow_arrayref failed: opendir/) or print "got: $err2\n";

package main;

print "test HandleSetErr\n";

my $dbh = DBI->connect(@con_info);
$dbh->{RaiseError} = 1;
$dbh->{PrintError} = 1;
$dbh->{PrintWarn} = 1;

my %warn = ( failed => 0, warning => 0 );
my @handlewarn = (0,0,0);
$SIG{__WARN__} = sub {
    my $msg = shift;
    if ($msg =~ /^DBD::ExampleP::\S+\s+(\S+)\s+(\w+)/) {
	++$warn{$2};
	$msg =~ s/\n/\\n/g;
	print "warn: '$msg'\n";
	return;
    }
    warn $msg;
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
ok(!defined $DBI::err);

$dbh->set_err("", "(got info)");
is(defined $DBI::err, 1);	# true
is($DBI::err, "");
is($DBI::errstr, "(got info)");
is($dbh->errstr, "(got info)");
is($warn{failed}, 0);
is($warn{warning}, 0);
is("@handlewarn", "1 0 0");

$dbh->set_err(0, "(got warn)", "AA001");	# triggers PrintWarn
ok(defined $DBI::err);
is($DBI::err, "0");
is($DBI::errstr, "(got info)\n(got warn)");
is($dbh->errstr, "(got info)\n(got warn)");
is($warn{warning}, 1);
is("@handlewarn", "1 1 0");
is($DBI::state, "AA001");

$dbh->set_err("", "(got more info)");		# triggers PrintWarn
ok(defined $DBI::err);
is($DBI::err, "0");	# not "", ie it's still a warn
is($dbh->err, "0");
is($DBI::errstr, "(got info)\n(got warn)\n(got more info)");
is($dbh->errstr, "(got info)\n(got warn)\n(got more info)");
is($warn{warning}, 2);
is("@handlewarn", "2 1 0");
is($DBI::state, "AA001");

$dbh->{RaiseError} = 0;
$dbh->{PrintError} = 1;

$dbh->set_err("42", "(got error)", "AA002");
is($DBI::err, 42);
is($dbh->errstr, "(got info)\n(got warn)\n(got more info) [state was AA001 now AA002]\n(got error)");
#is($warn{failed}, 1);
is($warn{warning}, 2);
is("@handlewarn", "2 1 1");
is($DBI::state, "AA002");

$dbh->set_err("", "(got info)");
is($DBI::err, 42);
is($dbh->errstr, "(got info)\n(got warn)\n(got more info) [state was AA001 now AA002]\n(got error)\n(got info)");
is($warn{warning}, 2);
is("@handlewarn", "3 1 1");

$dbh->set_err("0", "(got warn)"); # no PrintWarn because it's already an err
is($DBI::err, 42);
is($dbh->errstr, "(got info)\n(got warn)\n(got more info) [state was AA001 now AA002]\n(got error)\n(got info)\n(got warn)");
is($warn{warning}, 2);
is("@handlewarn", "3 2 1");

$dbh->set_err("4200", "(got new error)", "AA003");
is($DBI::err, 4200);
is($dbh->errstr, "(got info)\n(got warn)\n(got more info) [state was AA001 now AA002]\n(got error)\n(got info)\n(got warn) [err was 42 now 4200] [state was AA002 now AA003]\n(got new error)");
is($warn{warning}, 2);
is("@handlewarn", "3 2 2");

$dbh->set_err(undef, "foo", "bar"); # clear error
ok(!defined $dbh->errstr);
ok(!defined $dbh->err);
is($dbh->state, "");


%warn = ( failed => 0, warning => 0 );
@handlewarn = (0,0,0);
my @ret;
@ret = $dbh->set_err(1, "foo");		# PrintError
is(scalar @ret, 1);
ok(!defined $ret[0]);
ok(!defined $dbh->set_err(2, "bar"));	# PrintError
ok(!defined $dbh->set_err(3, "baz"));	# PrintError
ok(!defined $dbh->set_err(0, "warn"));	# PrintError
is($dbh->errstr, "foo [err was 1 now 2]\nbar [err was 2 now 3]\nbaz\nwarn");
is($warn{failed}, 4);
is("@handlewarn", "0 1 3");

$dbh->set_err(undef, undef, undef);	# clear error
@ret = $dbh->set_err(1, "foo", "AA123", "method");
is(scalar @ret, 1);
ok(!defined $ret[0]);
@ret = $dbh->set_err(1, "foo", "AA123", "method", "42");
is(scalar @ret, 1);
is($ret[0], "42");
@ret = $dbh->set_err(1, "foo", "return");
is(scalar @ret, 0);

$dbh->set_err(undef, undef, undef);	# clear error
@ret = $dbh->set_err("", "info", "override");
is(scalar @ret, 1);
ok(!defined $ret[0]);
is($dbh->err,    99);
is($dbh->errstr, "errstr99");
is($dbh->state,  "OV123");

# end
