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
    return print "ok $t\n" if @_<3 && $got;
    return print "ok $t\n" if $got eq $want;
    warn "Test $n: wanted '$want', got '$got'\n";
    print "not ok $t\n";
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

BEGIN { $tests = 2 }
