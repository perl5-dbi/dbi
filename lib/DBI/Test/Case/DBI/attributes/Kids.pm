use strict;
use warnings;
use Test::More;

our @DB_CREDS = ('dbi:SQLite::memory:', undef, undef, {});
my %SQLS = (
  'SELECT' => 'SELECT 1+1',
  'INSERT' => undef
);

#We must force DBI to load the driver in order for it to be visible in the installed_drivers hash
#installed_drivers only list loaded drivers from a DBI perspective, not from a perl perspective.
#Hence 'use DBD::somedriver' is not loaded from a internal DBI perspective
DBI->connect( @DB_CREDS[0..2], {} );

{ #Check that Kids called on a Drive handle returns the number of databasehandlers created from this drive handle
    
  #Extracting the drivername from the dsn. We need to drivername to check that the driver keeps track of created database handles
  my $driver_name;
  ($driver_name = $DB_CREDS[0]) =~ s/dbi:([A-Za-z0-9_\-]+)::.+/$1/;
  
  my %drivers = DBI->installed_drivers();
  
  my $driver = $drivers{$driver_name};
  isa_ok($driver, 'DBI::dr');
  
  #Creating some database handles
  my @handlers = (DBI->connect( @DB_CREDS ));
  {
    #Inside another block, will go out of scope, and should not be counted
    my $dbh2 = DBI->connect( @DB_CREDS );
    isa_ok($dbh2, 'DBI::db');
  }
  push(@handlers, DBI->connect( @DB_CREDS ));
  isa_ok($_, 'DBI::db') for @handlers;

  cmp_ok($driver->{Kids}, '==', scalar(@handlers), $driver_name . '->{Kids} gives ' . scalar(@handlers));
  cmp_ok($driver->FETCH('Kids'), '==', scalar(@handlers), $driver_name . '->FETCH(Kids) gives ' . scalar(@handlers));
}

{ #Check that database handles keep track of the statement handlers it has created
  my $dbh = DBI->connect( @DB_CREDS );
  isa_ok($dbh, 'DBI::db');
  
  #Creating some statementhandlers
  my @handlers = ($dbh->prepare( $SQLS{SELECT} ));
  {
    #Will go out of scope, and should not be counted against the number of Kids
    my $sth = $dbh->prepare( $SQLS{SELECT} );
    isa_ok($sth, 'DBI::st');
  }
  push(@handlers, $dbh->prepare( $SQLS{SELECT} ));
  isa_ok($_, 'DBI::st') for @handlers;
  
  cmp_ok($dbh->{Kids}, '==', scalar(@handlers), 'dbh->{Kids} reports a count of ' . scalar(@handlers) . ' statement handlers');
  cmp_ok($dbh->FETCH('Kids'), '==', scalar(@handlers), 'dbh->FETCH(Kids) reports a count of ' . scalar(@handlers) . ' statement handlers');
}

{ #A statement handler should have Kids automaticly set to 0
  my $dbh = DBI->connect( @DB_CREDS );
  isa_ok($dbh, 'DBI::db');
  
  my $sth = $dbh->prepare( $SQLS{SELECT} );
  isa_ok($sth, 'DBI::st');
  cmp_ok($sth->{Kids}, '==', 0, 'sth->{Kids} returns 0');
  cmp_ok($sth->FETCH('Kids'), '==', 0, 'sth->FETCH(Kids) returns 0');
}

done_testing();