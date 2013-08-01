#!perl -w
$| = 1;

use strict;
use warnings;

use File::Copy ();
use File::Path;
use File::Spec ();
use Test::More;

my $using_dbd_gofer = ( $ENV{DBI_AUTOPROXY} || '' ) =~ /^dbi:Gofer.*transport=/i;

use DBI;

do "t/lib.pl";

my $dir = test_dir();

my $dbh = DBI->connect( 'dbi:DBM:', undef, undef, {
      f_dir               => $dir,
      sql_identifier_case => 1,      # SQL_IC_UPPER
    }
);

ok( $dbh->do(q/drop table if exists FRED/), 'drop table' );

my $dirfext = $^O eq 'VMS' ? '.sdbm_dir' : '.dir';

$dbh->do(q/create table fred (a integer, b integer)/);
ok( -f File::Spec->catfile( $dir, "FRED$dirfext" ), "FRED$dirfext exists" );

rmtree $dir;
mkpath $dir;

if ($using_dbd_gofer)
{
    # can't modify attributes when connect through a Gofer instance
    $dbh->disconnect();
    $dbh = DBI->connect( 'dbi:DBM:', undef, undef, {
          f_dir               => $dir,
          sql_identifier_case => 2,      # SQL_IC_LOWER
        }
    );
}
else
{
    $dbh->dbm_clear_meta('fred');         # otherwise the col_names are still known!
    $dbh->{sql_identifier_case} = 2;      # SQL_IC_LOWER
}

$dbh->do(q/create table FRED (a integer, b integer)/);
ok( -f File::Spec->catfile( $dir, "fred$dirfext" ), "fred$dirfext exists" );

my $tblfext;
unless( $using_dbd_gofer )
{
       $tblfext = $dbh->{dbm_tables}->{fred}->{f_ext} || '';
       $tblfext =~ s{/r$}{};
    ok( -f File::Spec->catfile( $dir, "fred$tblfext" ), "fred$tblfext exists" );
}

ok( $dbh->do(q/insert into fRED (a,b) values(1,2)/), 'insert into mixed case table' );

# but change fRED to FRED and it works.

ok( $dbh->do(q/insert into FRED (a,b) values(2,1)/), 'insert into uppercase table' );

unless ($using_dbd_gofer)
{
    my $fn_tbl2 = $dbh->{dbm_tables}->{fred}->{f_fqfn};
       $fn_tbl2 =~ s/fred(\.[^.]*)?$/freddy$1/;
    my @dbfiles = grep { -f $_ } (
				     $dbh->{dbm_tables}->{fred}->{f_fqfn},
				     $dbh->{dbm_tables}->{fred}->{f_fqln},
				     $dbh->{dbm_tables}->{fred}->{f_fqbn} . ".dir"
				 );
    foreach my $fn (@dbfiles)
    {
	my $tgt_fn = $fn;
	$tgt_fn =~ s/fred(\.[^.]*)?$/freddy$1/;
	File::Copy::copy( $fn, $tgt_fn );
    }
    $dbh->{dbm_tables}->{krueger}->{file} = $fn_tbl2;

    my $r = $dbh->selectall_arrayref(q/select * from Krueger/);
    ok( @$r == 2, 'rows found via cloned mixed case table' );

    ok( $dbh->do(q/drop table if exists KRUeGEr/), 'drop table' );
}

my $r = $dbh->selectall_arrayref(q/select * from Fred/);
ok( @$r == 2, 'rows found via mixed case table' );

SKIP:
{
    DBD::DBM::Statement->isa("SQL::Statement") or skip("quoted identifiers aren't supported by DBI::SQL::Nano",1);
    my $abs_tbl = File::Spec->catfile( $dir, 'fred' );
       # work around SQL::Statement bug
       DBD::DBM::Statement->isa("SQL::Statement") and SQL::Statement->VERSION() lt "1.32" and $abs_tbl =~ s|\\|/|g;
       $r = $dbh->selectall_arrayref( sprintf( q|select * from "%s"|, $abs_tbl ) );
    ok( @$r == 2, 'rows found via select via fully qualified path' );
}

if( $using_dbd_gofer )
{
    ok( $dbh->do(q/drop table if exists FRED/), 'drop table' );
    ok( !-f File::Spec->catfile( $dir, "fred$dirfext" ), "fred$dirfext removed" );
}
else
{
    my $tbl_info = { file => "fred$tblfext" };

    ok( $dbh->disconnect(), "disconnect" );
    $dbh = DBI->connect( 'dbi:DBM:', undef, undef, {
	  f_dir               => $dir,
	  sql_identifier_case => 2,      # SQL_IC_LOWER
	  dbm_tables          => { fred => $tbl_info },
	}
    );

    my @tbl;
    @tbl = $dbh->tables (undef, undef, undef, undef);
    is( scalar @tbl, 1, "Found 1 tables");

       $r = $dbh->selectall_arrayref(q/select * from Fred/);
    ok( @$r == 2, 'rows found after reconnect using "dbm_tables"' );

    my $deep_dir = File::Spec->catdir( $dir, 'deep' );
    mkpath $deep_dir;

    $dbh = DBI->connect( 'dbi:DBM:', undef, undef, {
	  f_dir               => $deep_dir,
	  sql_identifier_case => 2,      # SQL_IC_LOWER
	}
    );
    ok( $dbh->do( q{create table wilma (a integer, b char (10))} ), "Create wilma" );
    ok( $dbh->do( q{insert into wilma values (1, 'Barney')} ), "insert Barney" );
    ok( $dbh->disconnect(), "disconnect" );

    $dbh = DBI->connect( 'dbi:DBM:', undef, undef, {
	  f_dir               => $dir,
	  sql_identifier_case => 2,      # SQL_IC_LOWER
	}
    );

    # Make sure wilma is not found without f_dir_search
    @tbl = $dbh->tables (undef, undef, undef, undef);
    is( scalar @tbl, 1, "Found 1 table");
    ok( $dbh->disconnect(), "disconnect" );

    $dbh = DBI->connect( 'dbi:DBM:', undef, undef, {
	  f_dir               => $dir,
	  f_dir_search        => [ $deep_dir ],
	  sql_identifier_case => 2,      # SQL_IC_LOWER
	}
    );

    @tbl = $dbh->tables (undef, undef, undef, undef);
    is( scalar @tbl, 2, "Found 2 tables");
    # f_dir should always appear before f_dir_search
    like( $tbl[0], qr{(?:^|\.)fred$}i,  "Fred first" );
    like( $tbl[1], qr{(?:^|\.)wilma$}i, "Fred second" );

    my( $n, $sth );
    ok( $sth = $dbh->prepare( 'select * from fred' ), "select from fred" );
    ok( $sth->execute, "execute fred" );
    $n = 0;
    $n++ while $sth->fetch;
    is( $n, 2, "2 entry in fred" );
    ok( $sth = $dbh->prepare( 'select * from wilma' ), "select from wilma" );
    ok( $sth->execute, "execute wilma" );
    $n = 0;
    $n++ while $sth->fetch;
    is( $n, 1, "1 entry in wilma" );

    ok( $dbh->do(q/drop table if exists FRED/), 'drop table fred' );
    ok( !-f File::Spec->catfile( $dir, "fred$dirfext" ), "fred$dirfext removed" );
    ok( !-f File::Spec->catfile( $dir, "fred$tblfext" ), "fred$tblfext removed" );

    ok( $dbh->do(q/drop table if exists wilma/), 'drop table wilma' );
    ok( !-f File::Spec->catfile( $deep_dir, "wilma$dirfext" ), "wilma$dirfext removed" );
    ok( !-f File::Spec->catfile( $deep_dir, "wilma$tblfext" ), "wilma$tblfext removed" );
}

done_testing();
