use strict;
use warnings;
use Test::More;

our @DB_CREDS = ('dbi:SQLite::memory:', undef, undef, {});
my %SQLS = (
  'SELECT' => 'SELECT 1+1',
  'INSERT' => undef
);

{ #Check that Kids called on a Drive handle returns the number of databasehandlers created from this drive handle
    
  #Extracting the drivername from the dsn. We need to drivername to check that the driver keeps track of created database handles
  my $driver_name;
  ($driver_name = $DB_CREDS[0]) =~ s/dbi:([A-Za-z0-9_\-]+)::.+/$1/;
  
  my %drivers = DBI->installed_drivers();
  my $driver = $drivers{$driver_name};
  isa_ok($driver, 'DBI::dr');
  
  #Creating some database handles
  my @active_dbhs = (DBI->connect( @DB_CREDS ));
  {
    #Inside another block, will go out of scope, and should not be counted
    my $dbh = DBI->connect( @DB_CREDS );
    isa_ok($dbh, 'DBI::db');
  }
  push(@active_dbhs, DBI->connect( @DB_CREDS ));
  isa_ok($_, 'DBI::db') for @active_dbhs;
  
  #This one should not be counted, since disconnect will turn Active to false
  my $dbh = DBI->connect( @DB_CREDS );
  isa_ok($dbh, 'DBI::db');
  ok($dbh->disconnect(), 'disconnect'); #Will turn active off
  
  cmp_ok($driver->{ActiveKids}, '==', scalar(@active_dbhs), $driver_name . "->{ActiveKids} reports " . scalar(@active_dbhs) . " active database handles");
  cmp_ok($driver->FETCH('ActiveKids'), '==', scalar(@active_dbhs), $driver_name . "->FETCH(ActiveKids) reports " . scalar(@active_dbhs) . " active database handles");
}

{ #Check the that Active is true if a statement handler has more rows to fetch

  TODO : {
    local $TODO = "Must mock a sth to have more rows to fetch";
    
    my $dbh = DBI->connect( @DB_CREDS[0..2], {} );
    isa_ok($dbh, 'DBI::db');
    
    my @active_sths = ();
    
    for(1..10){ #Put 10 statementhandlers in the array
      my $sth = $dbh->prepare($SQLS{SELECT});
      isa_ok($sth, 'DBI::st');
      ok($sth->execute(), 'execute sth #' . $_);
    }
    
    #TODO : make sure sth has more rows to fetch

    my $finished_sth = shift @active_sths;
    ok($finished_sth->finish(), 'finished() a statementhandler'); #Should not count towards ActiveKids count
    
    my $fetchall_sth = shift @active_sths;
    my $data = $fetchall_sth->fetchall_arrayref;
    
    cmp_ok($dbh->{ActiveKids}, '==', scalar(@active_sths), "dbh->{ActiveKids} reports " . scalar(@active_sths) . " active statement handlers");
    cmp_ok($dbh->FETCH('ActiveKids'), '==', scalar(@active_sths), "dbh->FETCH(ActiveKids) reports " . scalar(@active_sths) . " active statement handlers");
  }
}

{ #A statement handler should have Kids automaticly set to 0
  my $dbh = DBI->connect( @DB_CREDS );
  isa_ok($dbh, 'DBI::db');
  
  my $sth = $dbh->prepare( $SQLS{SELECT} );
  isa_ok($sth, 'DBI::st');
  
  cmp_ok($sth->{ActiveKids}, '==', 0, 'sth->{ActiveKids} ==  0');
  cmp_ok($sth->FETCH('ActiveKids'), '==', 0, 'sth->FETCH(ActiveKids) == 0');
}

done_testing();