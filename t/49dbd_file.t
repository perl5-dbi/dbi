#!perl -w
$|=1;

use strict;

use Cwd;
use File::Path;
use File::Spec;
use Test::More;

my $using_dbd_gofer = ($ENV{DBI_AUTOPROXY}||"") =~ /^dbi:Gofer.*transport=/i;

my $tbl;
BEGIN { $tbl = "db_". $$ . "_" };
#END   { $tbl and unlink glob "${tbl}*" }

use_ok ("DBI");
use_ok ("DBD::File");

do "t/lib.pl";

my $dir = test_dir ();

my $rowidx = 0;
my @rows = ( [ "Hello World" ], [ "Hello DBI Developers" ], );

my $dbh;

# Check if we can connect at all
ok ($dbh = DBI->connect ("dbi:File:"), "Connect clean");
is (ref $dbh, "DBI::db", "Can connect to DBD::File driver");

my $f_versions = $dbh->func ("f_versions");
note $f_versions;
ok ($f_versions, "f_versions");

# Check if all the basic DBI attributes are accepted
ok ($dbh = DBI->connect ("dbi:File:", undef, undef, {
    RaiseError		=> 1,
    PrintError		=> 1,
    AutoCommit		=> 1,
    ChopBlanks		=> 1,
    ShowErrorStatement	=> 1,
    FetchHashKeyName	=> "NAME_lc",
    }), "Connect with DBI attributes");

# Check if all the f_ attributes are accepted, in two ways
ok ($dbh = DBI->connect ("dbi:File:f_ext=.txt;f_dir=.;f_encoding=cp1252;f_schema=test"), "Connect with driver attributes in DSN");

my $encoding = "iso-8859-1";

# now use dir to prove file existence
ok ($dbh = DBI->connect ("dbi:File:", undef, undef, {
    f_ext	=> ".txt",
    f_dir	=> $dir,
    f_schema	=> undef,
    f_encoding	=> $encoding,
    f_lock	=> 0,

    RaiseError	=> 0,
    PrintError	=> 0,
    }), "Connect with driver attributes in hash");

my $sth;
ok ($sth = $dbh->prepare ("select * from t_sbdgf_53442Gz"), "Prepare select from non-existing file");

{   my @msg;
    eval {
	local $SIG{__DIE__} = sub { push @msg, @_ };
	$sth->execute;
	};
    like ("@msg", qr{Cannot open .*t_sbdgf_}, "Cannot open non-existing file");
    eval {
        note $dbh->f_get_meta ("t_sbdgf_53442Gz", "f_fqfn");
        };
    }

SKIP: {
    my $fh;
    my $tbl2 = $tbl . "2";

    my $tbl2_file1 = File::Spec->catfile ($dir, "$tbl2.txt");
    open  $fh, ">", $tbl2_file1 or skip;
    print $fh "You cannot read this anyway ...";
    close $fh;

    my $tbl2_file2 = File::Spec->catfile ($dir, "$tbl2");
    open  $fh, ">", $tbl2_file2 or skip;
    print $fh "Neither that";
    close $fh;

    ok ($dbh->do ("drop table if exists $tbl2"), "drop manually created table $tbl2 (first file)");
    ok (! -f $tbl2_file1, "$tbl2_file1 removed");
    ok (  -f $tbl2_file2, "$tbl2_file2 exists");
    ok ($dbh->do ("drop table if exists $tbl2"), "drop manually created table $tbl2 (second file)");
    ok (! -f $tbl2_file2, "$tbl2_file2 removed");
    }

my @tfhl;

# Now test some basic SQL statements
my $tbl_file = File::Spec->catfile (Cwd::abs_path ($dir), "$tbl.txt");
ok ($dbh->do ("create table $tbl (txt varchar (20))"), "Create table $tbl") or diag $dbh->errstr;
ok (-f $tbl_file, "Test table exists");

is ($dbh->f_get_meta ($tbl, "f_fqfn"), $tbl_file, "get single table meta data");
is_deeply ($dbh->f_get_meta ([$tbl, "t_sbdgf_53442Gz"], [qw(f_dir f_ext)]),
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
	   "get multiple meta data");

# Expected: ("unix", "perlio", "encoding(iso-8859-1)")
# use Data::Peek; DDumper [ @tfh ];
my @layer = grep { $_ eq "encoding($encoding)" } @tfhl;
is (scalar @layer, 1, "encoding shows in layer");

my @tables = sort $dbh->func ("list_tables");
is_deeply (\@tables, [sort "000_just_testing", $tbl], "Listing tables gives test table");

ok ($sth = $dbh->table_info (), "table_info");
@tables = sort { $a->[2] cmp $b->[2] } @{$sth->fetchall_arrayref};
is_deeply (\@tables, [ map { [ undef, undef, $_, 'TABLE', 'FILE' ] } sort "000_just_testing", $tbl ], "table_info gives test table");

SKIP: {
    $using_dbd_gofer and skip "modifying meta data doesn't work with Gofer-AutoProxy", 4;
    ok ($dbh->f_set_meta ($tbl, "f_dir", $dir), "set single meta datum");
    is ($tbl_file, $dbh->f_get_meta ($tbl, "f_fqfn"), "verify set single meta datum");
    ok ($dbh->f_set_meta ($tbl, { f_dir => $dir }), "set multiple meta data");
    is ($tbl_file, $dbh->f_get_meta ($tbl, "f_fqfn"), "verify set multiple meta attributes");
    }

ok ($sth = $dbh->prepare ("select * from $tbl"), "Prepare select * from $tbl");
$rowidx = 0;
SKIP: {
    $using_dbd_gofer and skip "method intrusion didn't work with proxying", 1;
    ok ($sth->execute, "execute on $tbl");
    $dbh->errstr and diag $dbh->errstr;
    }

my $uctbl = uc ($tbl);
ok ($sth = $dbh->prepare ("select * from $uctbl"), "Prepare select * from $uctbl");
$rowidx = 0;
SKIP: {
    $using_dbd_gofer and skip "method intrusion didn't work with proxying", 1;
    ok ($sth->execute, "execute on $uctbl");
    $dbh->errstr and diag $dbh->errstr;
    }

# ==================== ReadOnly tests =============================
ok ($dbh = DBI->connect ("dbi:File:", undef, undef, {
    f_ext	=> ".txt",
    f_dir	=> $dir,
    f_schema	=> undef,
    f_encoding	=> $encoding,
    f_lock	=> 0,

    sql_meta    => {
	$tbl => {
	    col_names => [qw(txt)],
	    }
	},

    RaiseError	=> 0,
    PrintError	=> 0,
    ReadOnly    => 1,
    }), "ReadOnly connect with driver attributes in hash");

ok ($sth = $dbh->prepare ("select * from $tbl"), "Prepare select * from $tbl");
$rowidx = 0;
SKIP: {
    $using_dbd_gofer and skip "method intrusion didn't work with proxying", 1;
    ok ($sth->execute, "execute on $tbl");
    $dbh->errstr and diag $dbh->errstr;
    }

ok ($sth = $dbh->prepare ("insert into $tbl (txt) values (?)"), "prepare 'insert into $tbl'");
is ($sth->execute ("Perl rules"), undef, "insert failed intensionally");

ok ($sth = $dbh->prepare ("delete from $tbl"), "prepare 'delete from $tbl'");
is ($sth->execute (), undef, "delete failed intensionally");

is ($dbh->do ("drop table $tbl"), undef, "table drop failed intensionally");
is (-f $tbl_file, 1, "Test table not removed");

# ==================== ReadWrite again tests ======================
ok ($dbh = DBI->connect ("dbi:File:", undef, undef, {
    f_ext	=> ".txt",
    f_dir	=> $dir,
    f_schema	=> undef,
    f_encoding	=> $encoding,
    f_lock	=> 0,

    RaiseError	=> 0,
    PrintError	=> 0,
    }), "ReadWrite for drop connect with driver attributes in hash");

# XXX add a truncate test

ok ($dbh->do ("drop table $tbl"), "table drop");
is (-s $tbl_file, undef, "Test table removed"); # -s => size test

done_testing ();

sub DBD::File::Table::fetch_row ($$)
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

sub DBD::File::Table::push_names ($$$)
{
    my ($self, $data, $row_aryref) = @_;
    my $meta = $self->{meta};
    @tfhl = PerlIO::get_layers ($meta->{fh});
    @{$meta->{col_names}} = @{$row_aryref};
    } # push_names
