#!perl -wT

use lib qw(blib/arch blib/lib);	# needed since -T ignores PERL5LIB
#use blib;
use DBI qw(:sql_types);
use Config;
use Cwd;

$|=1;
$^W=1;

my $haveFileSpec = eval { require File::Spec };

print "1..$tests\n";

require VMS::Filespec if $^O eq 'VMS';

sub ok ($$;$) {
    my($n, $ok, $msg) = @_;
    $msg = (defined $msg) ? " ($msg)" : "";
    ++$t;
    die "sequence error, expected $n but actually $t at line ".(caller)[2]."\n"
		if $n and $n != $t;
    my $line = (caller)[2];
    ($ok) ? print "ok $t at line $line\n" : print "not ok $t\n";
    warn "# failed test $t at line ".(caller)[2]."$msg\n" unless $ok;
    return $ok;
}
	

my $trace_file = "dbitrace.log";
unlink $trace_file;
ok(0, !-e $trace_file);
my $orig_trace_level = DBI->trace;
DBI->trace(3,$trace_file);		# enable trace before first driver load

my $r;
my $dbh = DBI->connect('dbi:ExampleP(AutoCommit=>1):', undef, undef);
die "Unable to connect to ExampleP driver: $DBI::errstr" unless $dbh;
ok(0, $dbh);
ok(0, ref $dbh);
$dbh->dump_handle("dump_handle test, write to log file", 2);

DBI->trace(0, undef);	# turn off and restore to STDERR
if ($^O =~ /cygwin/i) { # cygwin has buffer flushing bug
	ok(0, 1);
} else {
	ok(0,  -s $trace_file, "trace file size = " . -s $trace_file);
}
unlink $trace_file;
ok(0, !-e $trace_file);

# internal hack to assist debugging using DBI_TRACE env var. See DBI.pm.
DBI->trace(@DBI::dbi_debug) if @DBI::dbi_debug;

$dbh->{Taint} = 1 unless $DBI::PurePerl;

my $dbh2;

eval {
    $dbh2 = DBI->connect("dbi:NoneSuch:foobar", 1, 1, { RaiseError=>1, AutoCommit=>0 });
};
ok(0, $@, $@);
ok(0, !$dbh2);

$dbh2 = DBI->connect('dbi:ExampleP:', '', '');
ok(0, $dbh ne $dbh2);
my $dbh3 = DBI->connect_cached('dbi:ExampleP:', '', '');
my $dbh4 = DBI->connect_cached('dbi:ExampleP:', '', '');
ok(0, $dbh3 eq $dbh4);
my $dbh5 = DBI->connect_cached('dbi:ExampleP:', '', '', { examplep_foo=>1 });
ok(0, $dbh5 ne $dbh4);

#$dbh->trace(2);
$dbh->{AutoCommit} = 1;
$dbh->{PrintError} = 0;
ok(0, $dbh->{Taint}      == 1) unless $DBI::PurePerl && ok(0,1);
ok(0, $dbh->{AutoCommit} == 1);
ok(0, $dbh->{PrintError} == 0);
#$dbh->trace(0); die;

ok(0, $dbh->{FetchHashKeyName} eq 'NAME');
ok(0, $dbh->{example_driver_path} =~ m:DBD/ExampleP.pm$:, $dbh->{example_driver_path});
#$dbh->trace(2);

print "quote\n";
ok(0, $dbh->quote("quote's") eq "'quote''s'");
ok(0, $dbh->quote("42", SQL_VARCHAR) eq "'42'");
ok(0, $dbh->quote("42", SQL_INTEGER) eq "42");
ok(0, $dbh->quote(undef)     eq "NULL");

print "quote_identifier\n";
my $get_info = $dbh->{examplep_get_info} || {};
$get_info->{29}  ='"'; # SQL_IDENTIFIER_QUOTE_CHAR
$dbh->{examplep_get_info} = $get_info;	# trigger STORE

ok(0, $dbh->quote_identifier('foo')    eq '"foo"',  $dbh->quote_identifier('foo'));
ok(0, $dbh->quote_identifier('f"o')    eq '"f""o"', $dbh->quote_identifier('f"o'));
ok(0, $dbh->quote_identifier('foo','bar') eq '"foo"."bar"');
ok(0, $dbh->quote_identifier(undef,undef,'bar') eq '"bar"');

$get_info->{41}  ='@'; # SQL_CATALOG_NAME_SEPARATOR
$get_info->{114} = 2;  # SQL_CATALOG_LOCATION
$dbh->{examplep_get_info} = $get_info;	# trigger STORE
ok(0, $dbh->quote_identifier('foo',undef,'bar') eq '"foo"."bar"');

$dbh->{dbi_quote_identifier_cache} = undef; # force cache refresh
ok(0, $dbh->quote_identifier('foo',undef,'bar') eq '"bar"@"foo"', $dbh->quote_identifier('foo',undef,'bar'));

print "others\n";
eval { $dbh->commit('dummy') };
ok(0, $@ =~ m/DBI commit: invalid number of arguments:/, $@)
	unless $DBI::PurePerl && ok(0,1);

ok(0, $dbh->ping);

# --- errors
my $cursor_e = $dbh->prepare("select unknown_field_name from ?");
ok(0, !defined $cursor_e);
ok(0, $DBI::err);
ok(0, $DBI::errstr =~ m/Unknown field names: unknown_field_name/);
ok(0, $DBI::err    == $dbh->err,    "DBI::err='$DBI::err', dbh->err=".$dbh->err);
ok(0, $DBI::errstr eq $dbh->errstr, "DBI::errstr='$DBI::errstr', dbh->errstr=".$dbh->errstr);

# --- func
ok(0, $dbh->errstr eq $dbh->func('errstr'));

foreach(17..19) { ok(0, 1) }	# soak up to next round number

my $std_sql = "select mode,size,name from ?";
my $csr_a = $dbh->prepare($std_sql);
ok(0, ref $csr_a);
ok(0, $csr_a->{NUM_OF_FIELDS} == 3);

unless ($DBI::PurePerl) {
    ok(0, tied %{ $csr_a->{Database} });	# ie is 'outer' handle
    ok(0, $csr_a->{Database} eq $dbh, "$csr_a->{Database} ne $dbh")
	unless $dbh->{mx_handle_list} && ok(0,1); # skip for Multiplex tests
    ok(0, tied %{ $csr_a->{Database}->{Driver} });	# ie is 'outer' handle
}
else {
    ok(0,1) foreach 1..3;
}
my $driver_name = $csr_a->{Database}->{Driver}->{Name};
ok(0, $driver_name eq 'ExampleP', $driver_name);

# --- FetchHashKeyName
$dbh->{FetchHashKeyName} = 'NAME_uc';
my $csr_b = $dbh->prepare($std_sql);
ok(0, ref $csr_b);

ok(0, $csr_a != $csr_b);

ok(0, "@{$csr_b->{NAME_lc}}" eq "mode size name");	# before NAME
ok(0, "@{$csr_b->{NAME_uc}}" eq "MODE SIZE NAME");
ok(0, "@{$csr_b->{NAME}}"    eq "mode size name");
ok(0, "@{$csr_b->{ $csr_b->{FetchHashKeyName} }}" eq "MODE SIZE NAME");

ok(0, "@{[sort keys   %{$csr_b->{NAME_lc_hash}}]}" eq "mode name size");
ok(0, "@{[sort values %{$csr_b->{NAME_lc_hash}}]}" eq "0 1 2");
ok(0, "@{[sort keys   %{$csr_b->{NAME_uc_hash}}]}" eq "MODE NAME SIZE");
ok(0, "@{[sort values %{$csr_b->{NAME_uc_hash}}]}" eq "0 1 2");

if ($DBI::PurePerl) {
    warn " Taint mode switching tests skipped\n";
    ok(0,1) foreach (1..15);
} else {
    # Check Taint* attribute switching

    #$dbh->{'Taint'} = 1; # set in connect
    ok(0, $dbh->{'Taint'});
    ok(0, $dbh->{'TaintIn'} == 1);
    ok(0, $dbh->{'TaintOut'} == 1);

    $dbh->{'TaintOut'} = 0;
    ok(0, $dbh->{'Taint'} == 0);
    ok(0, $dbh->{'TaintIn'} == 1);
    ok(0, $dbh->{'TaintOut'} == 0);

    $dbh->{'Taint'} = 0;
    ok(0, $dbh->{'Taint'} == 0);
    ok(0, $dbh->{'TaintIn'} == 0);
    ok(0, $dbh->{'TaintOut'} == 0);

    $dbh->{'TaintIn'} = 1;
    ok(0, $dbh->{'Taint'} == 0);
    ok(0, $dbh->{'TaintIn'} == 1);
    ok(0, $dbh->{'TaintOut'} == 0);

    $dbh->{'TaintOut'} = 1;
    ok(0, $dbh->{'Taint'} == 1);
    ok(0, $dbh->{'TaintIn'} == 1);
    ok(0, $dbh->{'TaintOut'} == 1);
}

# get a dir always readable on all platforms
my $dir = getcwd() || cwd();
$dir = VMS::Filespec::unixify($dir) if $^O eq 'VMS';
# untaint $dir
$dir =~ m/(.*)/; $dir = $1|| die;


# ---

my($col0, $col1, $col2, $rows);
my(@row_a, @row_b);

ok(0, $csr_a->{Taint} = 1) unless $DBI::PurePerl && ok(0,1);
#$csr_a->trace(5);
ok(0, $csr_a->bind_columns(undef, \($col0, $col1, $col2)) );
ok(0, $csr_a->execute( $dir ), $DBI::errstr);

@row_a = $csr_a->fetchrow_array;
ok(0, @row_a);

# check bind_columns
ok(0, $row_a[0] eq $col0) or print "$row_a[0] ne $col0\n";
ok(0, $row_a[1] eq $col1) or print "$row_a[1] ne $col1\n";
ok(0, $row_a[2] eq $col2) or print "$row_a[2] ne $col2\n";
#$csr_a->trace(0);

# Check Taint attribute works. This requires this test to be run
# manually with the -T flag: "perl -T -Mblib t/examp.t"
sub is_tainted {
    my $foo;
    return ! eval { ($foo=join('',@_)), kill 0; 1; };
}
if (is_tainted($^X) && !$DBI::PurePerl) {
    print "Taint attribute test enabled\n";
    $dbh->{'Taint'} = 0;
    my $st;
    eval { $st = $dbh->prepare($std_sql); };
    ok(0, ref $st);

    ok(0, $st->{'Taint'} == 0);

    ok(0, $st->execute( $dir ));

    my @row = $st->fetchrow_array;
    ok(0, @row);

    ok(0, !is_tainted($row[0]));
    ok(0, !is_tainted($row[1]));
    ok(0, !is_tainted($row[2]));

    $st->{'TaintIn'} = 1;

    @row = $st->fetchrow_array;
    ok(0, @row);

    ok(0, !is_tainted($row[0]));
    ok(0, !is_tainted($row[1]));
    ok(0, !is_tainted($row[2]));

    $st->{'TaintOut'} = 1;

    @row = $st->fetchrow_array;
    ok(0, @row);

    ok(0, is_tainted($row[0]));
    ok(0, is_tainted($row[1]));
    ok(0, is_tainted($row[2]));

    $st->finish;

    # check simple method call values
    #ok(0, 1);
    # check simple attribute values
    #ok(0, 1); # is_tainted($dbh->{AutoCommit}) );
    # check nested attribute values (where a ref is returned)
    #ok(0, is_tainted($csr_a->{NAME}->[0]) );
    # check checking for tainted values

    $dbh->{'Taint'} = $csr_a->{'Taint'} = 1;
    eval { $dbh->prepare($^X); 1; };
    ok(0, $@ =~ /Insecure dependency/, $@);
    eval { $csr_a->execute($^X); 1; };
    ok(0, $@ =~ /Insecure dependency/, $@);
    undef $@;

    $dbh->{'TaintIn'} = $csr_a->{'TaintIn'} = 0;

    eval { $dbh->prepare($^X); 1; };
    ok(0, !$@);
    eval { $csr_a->execute($^X); 1; };
    ok(0, !$@);

    # Reset taint status to what it was before this block, so that
    # tests later in the file don't get confused
    $dbh->{'Taint'} = $csr_a->{'Taint'} = 1;
}
else {
    warn " Taint attribute tests skipped\n" unless $DBI::PurePerl;
    ok(0,1) foreach (1..19);
}

unless ($DBI::PurePerl) {
    $csr_a->{Taint} = 0;
    ok(0, $csr_a->{Taint} == 0);
} else {
    ok(0, 1);
}

ok(0, $csr_b->bind_param(1, $dir));
ok(0, $csr_b->execute());
@row_b = @{ $csr_b->fetchrow_arrayref };
ok(0, @row_b);

ok(0, "@row_a" eq "@row_b");
@row_b = $csr_b->fetchrow_array;
ok(0, "@row_a" ne "@row_b");

ok(0, $csr_a->finish);
ok(0, $csr_b->finish);

$csr_a = undef;	# force destruction of this cursor now
ok(0, 1);

print "fetchrow_hashref('NAME_uc')\n";
ok(0, $csr_b->execute());
my $row_b = $csr_b->fetchrow_hashref('NAME_uc');
ok(0, $row_b);
ok(0, $row_b->{MODE} == $row_a[0]);
ok(0, $row_b->{SIZE} == $row_a[1]);
ok(0, $row_b->{NAME} eq $row_a[2]);

print "fetchrow_hashref('ParamValues')\n";
ok(0, $csr_b->execute());
ok(0, !defined eval { $csr_b->fetchrow_hashref('ParamValues') } ); # PurePerl croaks

print "FetchHashKeyName\n";
ok(0, $csr_b->execute());
$row_b = $csr_b->fetchrow_hashref();
ok(0, $row_b);
ok(0, keys(%$row_b) == 3);
ok(0, $row_b->{MODE} == $row_a[0]);
ok(0, $row_b->{SIZE} == $row_a[1]);
ok(0, $row_b->{NAME} eq $row_a[2]);

print "fetchall_arrayref\n";
ok(0, $csr_b->execute());
$r = $csr_b->fetchall_arrayref;
ok(0, $r);
ok(0, @$r);
ok(0, $r->[0]->[0] == $row_a[0]);
ok(0, $r->[0]->[1] == $row_a[1]);
ok(0, $r->[0]->[2] eq $row_a[2]);

print "fetchall_arrayref array slice\n";
ok(0, $csr_b->execute());
$r = $csr_b->fetchall_arrayref([2,1]);
ok(0, $r && @$r);
ok(0, $r->[0]->[1] == $row_a[1]);
ok(0, $r->[0]->[0] eq $row_a[2]);

print "fetchall_arrayref hash slice\n";
ok(0, $csr_b->execute());
#$csr_b->trace(9);
$r = $csr_b->fetchall_arrayref({ SizE=>1, nAMe=>1});
ok(0, $r && @$r);
ok(0, $r->[0]->{SizE} == $row_a[1]);
ok(0, $r->[0]->{nAMe} eq $row_a[2]);

#$csr_b->trace(4);
print "fetchall_arrayref hash\n";
ok(0, $csr_b->execute());
$r = $csr_b->fetchall_arrayref({});
ok(0, $r);
ok(0, keys %{$r->[0]} == 3);
ok(0, "@{$r->[0]}{qw(MODE SIZE NAME)}" eq "@row_a", "'@{$r->[0]}{qw(MODE SIZE NAME)}' ne '@row_a'");
#$csr_b->trace(0);

# use Data::Dumper; warn Dumper([\@row_a, $r]);

$rows = $csr_b->rows;
ok(0, $rows > 0, "row count $rows");
ok(0, $rows == @$r, "$rows vs ".@$r);
ok(0, $rows == $DBI::rows, "$rows vs $DBI::rows");
#$csr_b->trace(0);

# ---

print "selectrow_array\n";
@row_b = $dbh->selectrow_array($std_sql, undef, $dir);
ok(0, @row_b == 3);
ok(0, "@row_b" eq "@row_a");

print "selectrow_hashref\n";
$r = $dbh->selectrow_hashref($std_sql, undef, $dir);
ok(0, keys %$r == 3);
ok(0, $r->{MODE} eq $row_a[0]);
ok(0, $r->{SIZE} eq $row_a[1]);
ok(0, $r->{NAME} eq $row_a[2]);

print "selectall_arrayref\n";
$r = $dbh->selectall_arrayref($std_sql, undef, $dir);
ok(0, $r);
ok(0, @{$r->[0]} == 3);
ok(0, "@{$r->[0]}" eq "@row_a");
ok(0, @$r == $rows);

print "selectall_arrayref Slice array slice\n";
$r = $dbh->selectall_arrayref($std_sql, { Slice => [ 2, 0 ] }, $dir);
ok(0, $r);
ok(0, @{$r->[0]} == 2);
ok(0, "@{$r->[0]}" eq "$row_a[2] $row_a[0]", qq{"@{$r->[0]}" eq "$row_a[2] $row_a[0]"});
ok(0, @$r == $rows);

print "selectall_arrayref Columns array slice\n";
$r = $dbh->selectall_arrayref($std_sql, { Columns => [ 3, 1 ] }, $dir);
ok(0, $r);
ok(0, @{$r->[0]} == 2);
ok(0, "@{$r->[0]}" eq "$row_a[2] $row_a[0]", qq{"@{$r->[0]}" eq "$row_a[2] $row_a[0]"});
ok(0, @$r == $rows);

print "selectall_arrayref hash slice\n";
$r = $dbh->selectall_arrayref($std_sql, { Columns => { MoDe=>1, NamE=>1 } }, $dir);
ok(0, $r);
ok(0, keys %{$r->[0]} == 2);
ok(0, exists $r->[0]{MoDe});
ok(0, exists $r->[0]{NamE});
ok(0, $r->[0]{MoDe} eq $row_a[0]);
ok(0, $r->[0]{NamE} eq $row_a[2]);
ok(0, @$r == $rows);

print "selectall_hashref\n";
$r = $dbh->selectall_hashref($std_sql, 'NAME', undef, $dir);
ok(0, $r, $r);
ok(0, ref $r eq 'HASH', ref $r);
ok(0, keys %$r == $rows, scalar keys %$r);
ok(0, $r->{ $row_a[2] }{SIZE} eq $row_a[1], qq{$r->{ $row_a[2] }{SIZE} eq $row_a[1]});

print "selectall_hashref by column number\n";
$r = $dbh->selectall_hashref($std_sql, 3, undef, $dir);
ok(0, $r);
ok(0, $r->{ $row_a[2] }{SIZE} eq $row_a[1], qq{$r->{ $row_a[2] }{SIZE} eq $row_a[1]});

print "selectcol_arrayref\n";
$r = $dbh->selectcol_arrayref($std_sql, undef, $dir);
ok(0, $r);
ok(0, @$r == $rows);
ok(0, $r->[0] eq $row_b[0]);

print "selectcol_arrayref column slice\n";
$r = $dbh->selectcol_arrayref($std_sql, { Columns => [3,2] }, $dir);
ok(0, $r);
# use Data::Dumper; warn Dumper([\@row_b, $r]);
ok(0, @$r == $rows * 2);
ok(0, $r->[0] eq $row_b[2]);
ok(0, $r->[1] eq $row_b[1]);

# ---

print "begin_work...\n";
ok(0, $dbh->{AutoCommit});
ok(0, !$dbh->{BegunWork});

ok(0, $dbh->begin_work);
ok(0, !$dbh->{AutoCommit}, $dbh->{AutoCommit});
ok(0, $dbh->{BegunWork});

$dbh->commit;
ok(0, $dbh->{AutoCommit});
ok(0, !$dbh->{BegunWork});

ok(0, $dbh->begin_work({}));
$dbh->rollback;
ok(0, $dbh->{AutoCommit});
ok(0, !$dbh->{BegunWork});

# ---

print "others...\n";
my $csr_c;
$csr_c = $dbh->prepare("select unknown_field_name1 from ?");
ok(0, !defined $csr_c);
ok(0, $DBI::errstr =~ m/Unknown field names: unknown_field_name1/);

print "RaiseError & PrintError & ShowErrorStatement\n";
$dbh->{RaiseError} = 1;
ok(0, $dbh->{RaiseError});
$dbh->{ShowErrorStatement} = 1;
ok(0, $dbh->{ShowErrorStatement});

my $error_sql = "select unknown_field_name2 from ?";

ok(0, ! eval { $csr_c = $dbh->prepare($error_sql); 1; });
#print "$@\n";
ok(0, $@ =~ m/\Q$error_sql/, $@); # ShowErrorStatement
ok(0, $@ =~ m/.*Unknown field names: unknown_field_name2/, $@);

my $se_sth1 = $dbh->prepare("select mode from ?");
ok(0, $se_sth1->{RaiseError});
ok(0, $se_sth1->{ShowErrorStatement});

# check that $dbh->{Statement} tracks last _executed_ sth
ok(0, $se_sth1->{Statement} eq "select mode from ?");
ok(0, $dbh->{Statement}     eq "select mode from ?") or print "got: $dbh->{Statement}\n";
my $se_sth2 = $dbh->prepare("select name from ?");
ok(0, $se_sth2->{Statement} eq "select name from ?");
ok(0, $dbh->{Statement}     eq "select name from ?");
$se_sth1->execute('.');
ok(0, $dbh->{Statement}     eq "select mode from ?");

# show error param values
ok(0, ! eval { $se_sth1->execute('first','second') });	# too many params
ok(0, $@ =~ /\b1='first'/, $@);
ok(0, $@ =~ /\b2='second'/, $@);

$se_sth1->finish;
$se_sth2->finish;

$dbh->{RaiseError} = 0;
ok(0, !$dbh->{RaiseError});
$dbh->{ShowErrorStatement} = 0;
ok(0, !$dbh->{ShowErrorStatement});

{
  my @warn;
  local($SIG{__WARN__}) = sub { push @warn, @_ };
  $dbh->{PrintError} = 1;
  ok(0, $dbh->{PrintError});
  ok(0, ! $dbh->selectall_arrayref("select unknown_field_name3 from ?"));
  ok(0, "@warn" =~ m/Unknown field names: unknown_field_name3/);
  $dbh->{PrintError} = 0;
  ok(0, !$dbh->{PrintError});
}


print "HandleError\n";
my $HandleErrorReturn;
my $HandleError = sub {
    my $msg = sprintf "HandleError: %s [h=%s, rv=%s, #=%d]",
		$_[0],$_[1],(defined($_[2])?$_[2]:'undef'),scalar(@_);
    die $msg   if $HandleErrorReturn < 0;
    print "$msg\n";
    $_[2] = 42 if $HandleErrorReturn == 2;
    return $HandleErrorReturn;
};
$dbh->{HandleError} = $HandleError;
ok(0, $dbh->{HandleError});
ok(0, $dbh->{HandleError} == $HandleError);

$dbh->{RaiseError} = 1;
$dbh->{PrintError} = 0;
$error_sql = "select unknown_field_name2 from ?";

print "HandleError -> die\n";
$HandleErrorReturn = -1;
ok(0, ! eval { $csr_c = $dbh->prepare($error_sql); 1; });
ok(0, $@ =~ m/^HandleError:/, $@);

print "HandleError -> 0 -> RaiseError\n";
$HandleErrorReturn = 0;
ok(0, ! eval { $csr_c = $dbh->prepare($error_sql); 1; });
ok(0, $@ =~ m/^DBD::(ExampleP|Multiplex)::db prepare failed:/, $@);

print "HandleError -> 1 -> return (original)undef\n";
$HandleErrorReturn = 1;
$r = eval { $csr_c = $dbh->prepare($error_sql); };
ok(0, !$@, $@);
ok(0, !defined($r), $r);

#$dbh->trace(4);

print "HandleError -> 2 -> return (modified)42\n";
$HandleErrorReturn = 2;
$r = eval { $csr_c = $dbh->prepare($error_sql); };
ok(0, !$@, $@);
ok(0, $r==42, $r) unless $dbh->{mx_handle_list} && ok(0,1); # skip for Multiplex

$dbh->{HandleError} = undef;
ok(0, !$dbh->{HandleError});

#$dbh->trace(0); die;

print "dump_results\n";
ok(0, $csr_a = $dbh->prepare($std_sql));
if ($haveFileSpec && length(File::Spec->updir))
{
  ok(0, $csr_a->execute(File::Spec->updir));
} else {
  ok(0, $csr_a->execute('../'));
}
my $dump_dir = ($ENV{TMP} || $ENV{TEMP} || $ENV{TMPDIR} 
               || $ENV{'SYS$SCRATCH'} || '/tmp');
my $dump_file = ($haveFileSpec)
    ? File::Spec->catfile($dump_dir, 'dumpcsr.tst')
    : "$dump_dir/dumpcsr.tst";
($dump_file) = ($dump_file =~ m/^(.*)$/);	# untaint
if (open(DUMP_RESULTS, ">$dump_file")) {
	ok(0, $csr_a->dump_results("10", "\n", ",\t", \*DUMP_RESULTS));
	close(DUMP_RESULTS);
	ok(0, -s $dump_file > 0);
} else {
	warn "# dump_results test skipped: unable to open $dump_file: $!\n";
	ok(0, 1);
	ok(0, 1);
}
unlink $dump_file;


print "table_info\n";
# First generate a list of all subdirectories
$dir = $haveFileSpec ? File::Spec->curdir() : ".";
ok(0, opendir(DIR, $dir));
my(%dirs, %unexpected, %missing);
while (defined(my $file = readdir(DIR))) {
    $dirs{$file} = 1 if -d $file;
}
closedir(DIR);
my $sth = $dbh->table_info(undef, undef, "%", "TABLE");
ok(0, $sth);
%unexpected = %dirs;
%missing = ();
while (my $ref = $sth->fetchrow_hashref()) {
    if (exists($unexpected{$ref->{'TABLE_NAME'}})) {
	delete $unexpected{$ref->{'TABLE_NAME'}};
    } else {
	$missing{$ref->{'TABLE_NAME'}} = 1;
    }
}
ok(0, keys %unexpected == 0)
    or print "Unexpected directories: ", join(",", keys %unexpected), "\n";
ok(0, keys %missing == 0)
    or print "Missing directories: ", join(",", keys %missing), "\n";


print "tables\n";
my @tables_expected = (
    q{"schema"."table"},
    q{"sch-ema"."table"},
    q{"schema"."ta-ble"},
    q{"sch ema"."table"},
    q{"schema"."ta ble"},
);
my @tables = $dbh->tables(undef, undef, "%", "VIEW");
ok(0, @tables == @tables_expected, "Table count mismatch".@tables_expected." vs ".@tables);
ok(0, $tables[$_] eq $tables_expected[$_], "$tables[$_] ne $tables_expected[$_]")
	foreach (0..$#tables_expected);


for (my $i = 0;  $i < 300;  $i += 100) {
	print "Testing the fake directories ($i).\n";
    ok(0, $csr_a = $dbh->prepare("SELECT name, mode FROM long_list_$i"));
    ok(0, $csr_a->execute(), $DBI::errstr);
    my $ary = $csr_a->fetchall_arrayref;
    ok(0, @$ary == $i, @$ary." rows instead of $i");
    if ($i) {
	my @n1 = map { $_->[0] } @$ary;
	my @n2 = reverse map { "file$_" } 1..$i;
	ok(0, "@n1" eq "@n2", "'@n1' ne '@n2'");
    }
    else {
	ok(0,1);
    }
}


print "Testing \$dbh->func().\n";
my %tables;
unless ($dbh->{mx_handle_list}) {
%tables = map { $_ =~ /lib/ ? ($_, 1) : () } $dbh->tables();
foreach my $t ($dbh->func('lib', 'examplep_tables')) {
    defined(delete $tables{$t}) or print "Unexpected table: $t\n";
}
}
ok(0, (%tables == 0));

$dbh->disconnect;
ok(0, !$dbh->{Active});

exit 0;

BEGIN { $tests = 246; }
