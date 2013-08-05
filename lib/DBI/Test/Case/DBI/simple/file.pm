package DBI::Test::Case::DBI::simple::file;

use strict;
use warnings;

use parent qw(DBI::Test::DBI::Case);

use Data::Dumper;

use Cwd;
use File::Path;
use File::Spec ();
use File::Copy ();

use Test::More;
use DBI::Test;

sub filter_drivers
{
    my ( $self, $options, @test_dbds ) = @_;
    return grep { $_ eq "File" or $_ eq "DBM" } @test_dbds;
}

# maybe we need to filter out mldbm or so ...
#sub supported_variant
#{
#}

my $using_dbd_gofer = ( $ENV{DBI_AUTOPROXY} || '' ) =~ /^dbi:Gofer.*transport=/i;

sub run_dbd_dbm_tests
{
    use_ok("DBD::DBM") or plan skip_all => "No DBD::DBM tests without DBD::DBM";

    my @DB_CREDS = @{ $_[1] };
    my $dir      = $DB_CREDS[3]->{f_dir} or plan skip_all => "Unprepared";
    my $dirfext  = $^O eq 'VMS' ? '.sdbm_dir' : '.dir';

    my $dbh = connect_ok(
        @DB_CREDS[ 0 .. 2 ],
        {
           %{ $DB_CREDS[3] },
           sql_identifier_case => 1,    # SQL_IC_UPPER
        },
        "Initial connect to $DB_CREDS[0]"
                        );

    do_ok( $dbh, q/drop table if exists FRED/, 'drop table' );

    do_ok( $dbh, q/create table fred (a integer, b integer)/, "CREATE TABLE FRED" );
    ok( -f File::Spec->catfile( $dir, "FRED$dirfext" ), "FRED$dirfext exists" );

    rmtree $dir;
    mkpath $dir;

    if ($using_dbd_gofer)
    {
        # can't modify attributes when connect through a Gofer instance
        $dbh->disconnect();
        $dbh = connect_ok(
            @DB_CREDS[ 0 .. 2 ],
            {
               %{ $DB_CREDS[3] },
               sql_identifier_case => 2,    # SQL_IC_LOWER
            },
            "Reconnect because of Gofer to $DB_CREDS[0] with SQL_IC_LOWER"
                         );
    }
    else
    {
        $dbh->dbm_clear_meta('fred');       # otherwise the col_names are still known!
        $dbh->{sql_identifier_case} = 2;    # SQL_IC_LOWER
    }

    do_ok( $dbh, q/create table FRED (a integer, b integer)/, "CREATE TABLE fred" );
    ok( -f File::Spec->catfile( $dir, "fred$dirfext" ), "fred$dirfext exists" );

    my $tblfext;
    unless ($using_dbd_gofer)
    {
        $tblfext = $dbh->{dbm_tables}->{fred}->{f_ext} || '';
        $tblfext =~ s{/r$}{};
        ok( -f File::Spec->catfile( $dir, "fred$tblfext" ), "fred$tblfext exists" );
    }

    do_ok( $dbh, q/insert into fRED (a,b) values(1,2)/, 'insert into mixed case table' );

    # but change fRED to FRED and it works.

    do_ok( $dbh, q/insert into FRED (a,b) values(2,1)/, 'insert into uppercase table' );

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

        do_ok( $dbh, q/drop table if exists KRUeGEr/, 'drop table' );
    }

    my $r = $dbh->selectall_arrayref(q/select * from Fred/);
    ok( @$r == 2, 'rows found via mixed case table' );

  SKIP:
    {
        DBD::DBM::Statement->isa("SQL::Statement")
          or skip( "quoted identifiers aren't supported by DBI::SQL::Nano", 1 );
        my $abs_tbl = File::Spec->catfile( $dir, 'fred' );
        # work around SQL::Statement bug
        DBD::DBM::Statement->isa("SQL::Statement")
          and SQL::Statement->VERSION() lt "1.32"
          and $abs_tbl =~ s|\\|/|g;
        $r = $dbh->selectall_arrayref( sprintf( q|select * from "%s"|, $abs_tbl ) );
        ok( @$r == 2, 'rows found via select via fully qualified path' );
    }

    if ($using_dbd_gofer)
    {
        ok( $dbh->do(q/drop table if exists FRED/), 'drop table' );
        ok( !-f File::Spec->catfile( $dir, "fred$dirfext" ), "fred$dirfext removed" );
    }
    else
    {
        my $tbl_info = { file => "fred$tblfext" };

        ok( $dbh->disconnect(), "disconnect" );
        $dbh = connect_ok(
            @DB_CREDS[ 0 .. 2 ],
            {
               %{ $DB_CREDS[3] },
               sql_identifier_case => 2,                       # SQL_IC_LOWER
               dbm_tables          => { fred => $tbl_info },
            },
            "Reconnect to $DB_CREDS[0] with prepared meta data"
                         );

        my @tbl;
        @tbl = $dbh->tables( undef, undef, undef, undef );
        is( scalar @tbl, 1, "Found 1 tables" );

        $r = $dbh->selectall_arrayref(q/select * from Fred/);
        ok( @$r == 2, 'rows found after reconnect using "dbm_tables"' );

        my $deep_dir = File::Spec->catdir( $dir, 'deep' );
        mkpath $deep_dir;

        $dbh = connect_ok(
            @DB_CREDS[ 0 .. 2 ],
            {
               %{ $DB_CREDS[3] },
               f_dir               => $deep_dir,
               sql_identifier_case => 2,           # SQL_IC_LOWER
            },
            "Reconnect to $DB_CREDS[0] with $deep_dir"
                         );

        do_ok( $dbh, q{create table wilma (a integer, b char (10))}, "Create wilma" );
        do_ok( $dbh, q{insert into wilma values (1, 'Barney')},      "insert Barney" );
        ok( $dbh->disconnect(), "disconnect" );

        $dbh = connect_ok(
            @DB_CREDS[ 0 .. 2 ],
            {
               %{ $DB_CREDS[3] },
               sql_identifier_case => 2,    # SQL_IC_LOWER
            },
            "Reconnect to roots $DB_CREDS[0] to prove sub-dirs are not searched"
                         );

        # Make sure wilma is not found without f_dir_search
        @tbl = $dbh->tables( undef, undef, undef, undef );
        is( scalar @tbl, 1, "Found 1 table" );
        ok( $dbh->disconnect(), "disconnect" );

        $dbh = connect_ok(
            @DB_CREDS[ 0 .. 2 ],
            {
               %{ $DB_CREDS[3] },
               f_dir_search        => [$deep_dir],
               sql_identifier_case => 2,             # SQL_IC_LOWER
            },
            "Reconnect to roots $DB_CREDS[0] with f_dir_search"
                         );

        @tbl = $dbh->tables( undef, undef, undef, undef );
        is( scalar @tbl, 2, "Found 2 tables" );
        # f_dir should always appear before f_dir_search
        like( $tbl[0], qr{(?:^|\.)fred$}i,  "Fred first" );
        like( $tbl[1], qr{(?:^|\.)wilma$}i, "Fred second" );

        my ( $n, $sth );
        $sth = prepare_ok( $dbh, 'select * from fred', "select from fred" );
        execute_ok( $sth, "execute fred" );
        $n = 0;
        $n++ while $sth->fetch;
        is( $n, 2, "2 entry in fred" );
        $sth = prepare_ok( $dbh, 'select * from wilma', "select from wilma" );
        execute_ok( $sth, "execute wilma" );
        $n = 0;
        $n++ while $sth->fetch;
        is( $n, 1, "1 entry in wilma" );

        do_ok( $dbh, q/drop table if exists FRED/, 'drop table fred' );
        ok( !-f File::Spec->catfile( $dir, "fred$dirfext" ), "fred$dirfext removed" );
        ok( !-f File::Spec->catfile( $dir, "fred$tblfext" ), "fred$tblfext removed" );

        do_ok( $dbh, q/drop table if exists wilma/, 'drop table wilma' );
        ok( !-f File::Spec->catfile( $deep_dir, "wilma$dirfext" ), "wilma$dirfext removed" );
        ok( !-f File::Spec->catfile( $deep_dir, "wilma$tblfext" ), "wilma$tblfext removed" );
    }

    done_testing();
}

my $dbd_file_table_methods_injected = 0;

sub run_dbd_file_tests
{
    use_ok("DBD::File") or plan skip_all => "No DBD::File tests without DBD::File";

    my @DB_CREDS = @{ $_[1] };
    my $dir = $DB_CREDS[3]->{f_dir} or plan skip_all => "Unprepared";
    my $tbl = "db_". $$ . "_";
    $dbd_file_table_methods_injected++ or eval q/

package DBD::File::Table;

our $rowidx = 0;
our @rows = ( [ "Hello World" ], [ "Hello DBI Developers" ], );
our @tfhl;

sub fetch_row
{
    my ($self, $data) = @_;
    my $meta = $self->{meta};
    if ($rowidx >= scalar @rows) {
	$self->{row} = undef;
	}
    else {
	$self->{row} = $rows[$rowidx++];
	}
    return $self->{row};
    } # fetch_row

sub push_names
{
    my ($self, $data, $row_aryref) = @_;
    my $meta = $self->{meta};
    @tfhl = PerlIO::get_layers ($meta->{fh});
    @{$meta->{col_names}} = @{$row_aryref};
    } # push_names

    1;
    /;
    $@ and diag($@);

    my $dsn_str =
      Data::Dumper->new( [ \@DB_CREDS ] )->Indent(0)->Sortkeys(1)->Quotekeys(0)->Terse(1)->Dump();

    # Check if we can connect at all
    my $dbh = connect_ok( @DB_CREDS, "Connect to $dsn_str" );
    is( ref $dbh, "DBI::db", "Can connect to DBD::File driver" );

    my $f_versions = $dbh->func("f_versions");
    note $f_versions;
    ok( $f_versions, "f_versions" );

    # Check if all the basic DBI attributes are accepted
    my @basic_creds = (
                        @DB_CREDS[ 0 .. 2 ],
                        {
                           RaiseError         => 1,
                           PrintError         => 1,
                           AutoCommit         => 1,
                           ChopBlanks         => 1,
                           ShowErrorStatement => 1,
                           FetchHashKeyName   => "NAME_lc",
                        }
                      );
    $dbh = connect_ok( @basic_creds, "Connect with DBI attributes" );

    my @dsnstr_creds = @DB_CREDS;
    $dsnstr_creds[0] .= "f_ext=.txt;f_dir=.;f_encoding=cp1252;f_schema=test";
    # Check if all the f_ attributes are accepted, in two ways
    $dbh = connect_ok( @basic_creds, "Connect with driver attributes in DSN" );

    # now use dir to prove file existence
    my $encoding = "iso-8859-1";
    my @encdsn = (
        @DB_CREDS[ 0 .. 2 ],
        {
           f_ext      => ".txt",
           f_dir      => $dir,
           f_schema   => undef,
           f_encoding => $encoding,
           f_lock     => 0,

           RaiseError => 0,
           PrintError => 0,
        }
    );
    $dbh = connect_ok( @encdsn, "Connect with driver attributes in hash" );

    my $sth = prepare_ok( $dbh, "select * from t_sbdgf_53442Gz", "Prepare select from non-existing file" );

    {
        my @msg;
        eval {
            local $SIG{__DIE__} = sub { push @msg, @_ };
            $sth->execute;
        };
        like( "@msg", qr{Cannot open .*t_sbdgf_}, "Cannot open non-existing file" );
        eval { note $dbh->f_get_meta( "t_sbdgf_53442Gz", "f_fqfn" ); };
    }

  SKIP:
    {
        my $fh;
        my $tbl2 = $tbl . "2";

        my $tbl2_file1 = File::Spec->catfile( $dir, "$tbl2.txt" );
        open $fh, ">", $tbl2_file1 or skip;
        print $fh "You cannot read this anyway ...";
        close $fh;

        my $tbl2_file2 = File::Spec->catfile( $dir, "$tbl2" );
        open $fh, ">", $tbl2_file2 or skip;
        print $fh "Neither that";
        close $fh;

        ok( $dbh->do("drop table if exists $tbl2"),
            "drop manually created table $tbl2 (first file)" );
        ok( !-f $tbl2_file1, "$tbl2_file1 removed" );
        ok( -f $tbl2_file2,  "$tbl2_file2 exists" );
        ok( $dbh->do("drop table if exists $tbl2"),
            "drop manually created table $tbl2 (second file)" );
        ok( !-f $tbl2_file2, "$tbl2_file2 removed" );
    }

    # Now test some basic SQL statements
    my $tbl_file = File::Spec->catfile( Cwd::abs_path($dir), "$tbl.txt" );
    do_ok( $dbh, "create table $tbl (txt varchar (20))", "Create table $tbl" ) or diag $dbh->errstr;
    ok( -f $tbl_file, "Test table exists" );

    is( $dbh->f_get_meta( $tbl, "f_fqfn" ), $tbl_file, "get single table meta data" );
    is_deeply(
               $dbh->f_get_meta( [ $tbl, "t_sbdgf_53442Gz" ], [qw(f_dir f_ext)] ),
               {
                  $tbl => {
                            f_dir => $dir,
                            f_ext => ".txt",
                          },
                  t_sbdgf_53442Gz => {
                                       f_dir => $dir,
                                       f_ext => ".txt",
                                     },
               },
               "get multiple meta data"
             );

    # Expected: ("unix", "perlio", "encoding(iso-8859-1)")
    # use Data::Peek; DDumper [ @tfh ];
    my @layer = grep { $_ eq "encoding($encoding)" } @DBD::File::Table::tfhl;
    is( scalar @layer, 1, "encoding shows in layer" );

    my @tables = sort $dbh->func("list_tables");
    is_deeply( \@tables, [ sort "000_just_testing", $tbl ], "Listing tables gives test table" );

    ok( $sth = $dbh->table_info(), "table_info" );
    @tables = sort { $a->[2] cmp $b->[2] } @{ $sth->fetchall_arrayref };
    is_deeply( \@tables,
               [ map { [ undef, undef, $_, 'TABLE', 'FILE' ] } sort "000_just_testing", $tbl ],
               "table_info gives test table" );

  SKIP:
    {
        $using_dbd_gofer and skip "modifying meta data doesn't work with Gofer-AutoProxy", 4;
        ok( $dbh->f_set_meta( $tbl, "f_dir", $dir ), "set single meta datum" );
        is( $tbl_file, $dbh->f_get_meta( $tbl, "f_fqfn" ), "verify set single meta datum" );
        ok( $dbh->f_set_meta( $tbl, { f_dir => $dir } ), "set multiple meta data" );
        is( $tbl_file, $dbh->f_get_meta( $tbl, "f_fqfn" ), "verify set multiple meta attributes" );
    }

    $sth = prepare_ok( $dbh, "select * from $tbl", "Prepare select * from $tbl" );
    $DBD::File::Table::rowidx = 0;
  SKIP:
    {
        $using_dbd_gofer and skip "method intrusion didn't work with proxying", 1;
        execute_ok( $sth, "execute on $tbl" );
        $dbh->errstr and diag $dbh->errstr;
    }

    my $uctbl = uc($tbl);
    $sth = prepare_ok( $dbh, "select * from $uctbl", "Prepare select * from $uctbl" );
    $DBD::File::Table::rowidx = 0;
  SKIP:
    {
        $using_dbd_gofer and skip "method intrusion didn't work with proxying", 1;
        execute_ok( $sth, "execute on $uctbl" );
        $dbh->errstr and diag $dbh->errstr;
    }

    # ==================== ReadOnly tests =============================
    my @rodsn = (
        @DB_CREDS[ 0 .. 2 ],
        {
           f_ext      => ".txt",
           f_dir      => $dir,
           f_schema   => undef,
           f_encoding => $encoding,
           f_lock     => 0,

           sql_meta => { $tbl => { col_names => [qw(txt)], } },

           RaiseError => 0,
           PrintError => 0,
           ReadOnly   => 1,
        }
    );
    $dbh = connect_ok( @rodsn, "ReadOnly connect with driver attributes in hash" );

    $sth = prepare_ok( $dbh, "select * from $tbl", "Prepare select * from $tbl" );
    $DBD::File::Table::rowidx = 0;
  SKIP:
    {
        $using_dbd_gofer and skip "method intrusion didn't work with proxying", 1;
        execute_ok( $sth, "execute on $tbl" );
        $dbh->errstr and diag $dbh->errstr;
    }

    $sth = prepare_ok( $dbh, "insert into $tbl (txt) values (?)", "prepare 'insert into $tbl'" );
    execute_not_ok( $sth, "Perl rules", "insert failed intensionally" );

    $sth = prepare_ok( $dbh, "delete from $tbl", "prepare 'delete from $tbl'" );
    execute_not_ok( $sth, "delete failed intensionally" );

    do_not_ok( $dbh, "drop table $tbl", "table drop failed intensionally" );
    is( -f $tbl_file, 1, "Test table not removed" );

    # ==================== ReadWrite again tests ======================
    $dbh = connect_ok(
        @DB_CREDS[ 0 .. 2 ],
        {
           f_ext      => ".txt",
           f_dir      => $dir,
           f_schema   => undef,
           f_encoding => $encoding,
           f_lock     => 0,

           RaiseError => 0,
           PrintError => 0,
        },
        "ReadWrite for drop connect with driver attributes in hash"
                     );

    # XXX add a truncate test

    do_ok( $dbh, "drop table $tbl", "table drop" );
    is( -s $tbl_file, undef, "Test table removed" );    # -s => size test

    done_testing();
}

sub run_test
{
    $_[1]->[0] =~ m/DBM/ and return $_[0]->run_dbd_dbm_tests( $_[1] );
    return $_[0]->run_dbd_file_tests( $_[1] );
}

1;
