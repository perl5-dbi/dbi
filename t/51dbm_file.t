#!perl -w
$|=1;

use strict;
use File::Path;
use File::Spec;
use Test::More;
use Cwd;

my $using_dbd_gofer = ($ENV{DBI_AUTOPROXY}||'') =~ /^dbi:Gofer.*transport=/i;

use DBI;

my $dir = File::Spec->catdir(getcwd(),'test_output');

rmtree $dir; END { rmtree $dir }
mkpath $dir;

my $dbh = DBI->connect('dbi:DBM:', undef, undef, {
    f_dir => $dir,
    sql_identifier_case => 1, # SQL_IC_UPPER
} ); 

ok($dbh->do(q/drop table if exists FRED/));

$dbh->do(q/create table fred (a integer, b integer)/);
ok(-f File::Spec->catfile( $dir, "FRED.dir" ), "FRED.dir exists");

rmtree $dir;
mkpath $dir;

if( $using_dbd_gofer )
{
    # can't modify attributes when connect through a Gofer instance
    $dbh->disconnect();
    $dbh = DBI->connect('dbi:DBM:', undef, undef, {
	f_dir => $dir,
	sql_identifier_case => 2, # SQL_IC_LOWER
    } ); 
}
else
{
    $dbh->dbm_clear_meta( 'fred' ); # otherwise the col_names are still known!
    $dbh->{sql_identifier_case} = 2; # SQL_IC_LOWER
}

$dbh->do(q/create table FRED (a integer, b integer)/);
ok(-f File::Spec->catfile( $dir, "fred.dir" ), "fred.dir exists");

ok($dbh->do(q/insert into fRED (a,b) values(1,2)/));

# but change fRED to FRED and it works.

ok($dbh->do(q/insert into FRED (a,b) values(2,1)/));

my $r = $dbh->selectall_arrayref(q/select * from Fred/);
ok(@$r == 2);

ok($dbh->do(q/drop table if exists FRED/));

done_testing();
