use strict;
use warnings;
use Test::More;

our @DB_CREDS = ('dbi:SQLite::memory:', undef, undef, { AutoCommit => 0});
my %SQLS = (
  'SELECT' => 'SELECT 1+1',
  'INSERT' => undef
);

{ #Check that calling execute on a statementhandler sets Executed to true on both the sth and the parent dbh
  
  my $dbh = DBI->connect( @DB_CREDS[0..2], {} );
  isa_ok($dbh, 'DBI::db');
  
  my $sth = $dbh->prepare($SQLS{INSERT});
  
  isa_ok($sth, 'DBI::st');
  
  ok($sth->execute(), 'execute');
  
  ok($sth->{Executed}, '$sth->{Executed} is true after execute() call');
  ok($sth->FETCH('Executed'), '$sth->FETCH(Executed) is true after execute() call');
  
  ok($dbh->{Executed}, '$dbh->{Executed} is true after execute() call');
  ok($dbh->FETCH('Executed'), '$dbh->FETCH(Executed) is true after execute() call');
}

{ #Check that the Executed flag is cleared on the database handle when a commit\rollback is issued
  
  foreach my $method ( qw(commit rollback) ){
    my $dbh = DBI->connect( @DB_CREDS[0..2], { AutoCommit => 0} );
    isa_ok($dbh, 'DBI::db');
    
    my $sth = $dbh->prepare($SQLS{INSERT});
    isa_ok($sth, 'DBI::st');
    
    ok($sth->execute(), 'execute');
    
    ok($sth->{Executed}, '$sth->{Executed} is true after execute() call');
    ok($sth->FETCH('Executed'), '$sth->FETCH(Executed) is true after execute() call');
  
    ok($dbh->{Executed}, '$dbh->{Executed} is true after execute() call');
    ok($dbh->FETCH('Executed'), '$dbh->FETCH(Executed) is true after execute() call');    
  
    ok($dbh->$method(), $method);
    
    #The Executed flag of the dbh should now be cleared by the commit or rollback call
    ok(!$dbh->{Executed}, '$dbh->{Executed} is false after ' . $method  . ' call');
    ok(!$dbh->FETCH('Executed'), '!$dbh->FETCH(Executed) is false after ' . $method  . ' call');
  }
}
done_testing();