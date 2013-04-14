use strict;
use warnings;
use Test::More;

our @DB_CREDS = ('dbi:SQLite::memory:', undef, undef, { AutoCommit => 0});
my %SQLS = (
  'SELECT' => 'SELECT 1+1',
  'INSERT' => undef
);

{ #Check that dbh->{Active} is true when connected, and false when disconnected
  
  my $dbh = DBI->connect( @DB_CREDS[0..2], {} );
  isa_ok($dbh, 'DBI::db');
  ok($dbh->{Active}, '$dbh->{Active} is true');
  ok($dbh->FETCH('Active'), '$dbh->FETCH(Active) is true');
  
  ok($dbh->disconnect(), 'disconnect');
  
  ok(!$dbh->{Active}, '$dbh->{Active} is false after disconnect');
  ok(!$dbh->FETCH('Active'), '$dbh->FETCH(Active) is false after disconnect');
}

{ #Check the that Active is true if a statement handler has more rows to fetch

  TODO : {
    local $TODO = "Must mock a sth to have more rows to fetch";
    
    my $dbh = DBI->connect( @DB_CREDS[0..2], {} );
    isa_ok($dbh, 'DBI::db');
    my $sth = $dbh->prepare($SQLS{SELECT});
    isa_ok($sth, 'DBI::st');
    
    ok($sth->execute(), 'execute');
    
    #TODO : make sure sth has more rows to fetch
    
    ok($sth->{Active}, '$sth->{Active} is true when it has more rows to fetch');
    ok($sth->FETCH('Active'), '$sth->FETCH(Active) is true when it has more rows to fetch');
  }
}

{ #Check the that Active is set to false after you have fetch all the data available

  TODO : {
    local $TODO = "Must mock a sth to have more rows to fetch";
    
    my $dbh = DBI->connect( @DB_CREDS[0..2], {} );
    isa_ok($dbh, 'DBI::db');
    my $sth = $dbh->prepare($SQLS{SELECT});
    
    isa_ok($sth, 'DBI::st');
    
    ok($sth->execute(), 'execute');
    
    #TODO : make sure sth has more rows to fetch
    
    ok($sth->{Active}, '$sth->{Active} is true when it has more rows to fetch');
    ok($sth->FETCH('Active'), '$sth->FETCH(Active) is true when it has more rows to fetch');
    
    my $data = $sth->fetchall_arrayref;
    
    #Active should now be false, since the sth should have no more rows to fetch
    ok(!$sth->{Active}, '$sth->{Active} is false after all data is fetched');
    ok(!$sth->FETCH('Active'), '$sth->FETCH(Active) is false after all data is fetched');
  }
}

{ #Check that Active is false if finished is called before we have fetched all rows

  TODO : {
    local $TODO = "Must mock a sth to have more rows to fetch";
    
    my $dbh = DBI->connect( @DB_CREDS[0..2], {} );
    isa_ok($dbh, 'DBI::db');
    
    my $sth = $dbh->prepare($SQLS{SELECT});
    isa_ok($sth, 'DBI::st');
    ok($sth->execute(), 'execute');
    
    #TODO : make sure sth has more rows to fetch
    
    ok($sth->{Active}, '$sth->{Active} is true when it has more rows to fetch');
    ok($sth->FETCH('Active'), '$sth->FETCH(Active) is true when it has more rows to fetch');
    
    ok($sth->finish(), 'finish');

    #Active should now be false, since finish() should set it to false
    ok(!$sth->{Active}, '$sth->{Active} is false after finish() call');
    ok(!$sth->FETCH('Active'), '$sth->FETCH(Active) is false after finish() call');
    
  }
}
done_testing();