use strict;
use warnings;
use Test::More;

our @DB_CREDS = ('dbi:SQLite::memory:', undef, undef, { AutoCommit => 0});
my %SQLS = (
  'SELECT' => 'SELECT 1+1',
  'INSERT' => undef
);

{ #Check that the driver object returns the correct type
  #Extracting the drivername from the dsn. We need to drivername to check that the driver returns the right type
  my $driver_name;
  ($driver_name = $DB_CREDS[0]) =~ s/dbi:([A-Za-z0-9_\-]+)::.+/$1/;
  
  #We must force DBI to load the driver in order for it to be visible in the installed_drivers hash
  #installed_drivers only list loaded drivers from a DBI perspective, not from a perl perspective.
  #Hence 'use DBD::somedriver' is not loaded from a internal DBI perspective
  my $dbh = DBI->connect( @DB_CREDS[0..2], {} );
  
  my %drivers = DBI->installed_drivers();

  my $driver = $drivers{$driver_name};
  isa_ok($driver, 'DBI::dr');
  
  cmp_ok($driver->{Type}, 'eq', 'dr', 'driver->{Type} eq dr');
  cmp_ok($driver->FETCH('Type'), 'eq', 'dr', 'driver->FETCH(Type) eq dr');
}
{ #Check that the database handle returns the correct type
  my $dbh = DBI->connect( @DB_CREDS[0..2], {} );
  isa_ok($dbh, 'DBI::db');
  cmp_ok($dbh->{Type}, 'eq', 'db', 'dbh->{Type} eq db');
  cmp_ok($dbh->FETCH('Type'), 'eq', 'db', 'dbh->FETCH(Type) eq db');
}
{ #Check that the statementhandler returns the correct type
  my $dbh = DBI->connect( @DB_CREDS[0..2], {} );
  isa_ok($dbh, 'DBI::db');
  
  my $sth = $dbh->prepare($SQLS{SELECT});
  isa_ok($sth, 'DBI::st');
  
  cmp_ok($sth->{Type}, 'eq', 'st', 'sth->{Type} eq st');
  cmp_ok($sth->FETCH('Type'), 'eq', 'st', 'sth->FETCH(Type) eq st');
}
done_testing();