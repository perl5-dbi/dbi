#!/usr/bin/perl
#
# Copyright Martin J. Evans
#
# Test unicode in a DBD - written for DBD::ODBC but should work for other
# DBDs if you change the column types at the start of this script.
#
# Usage:
#   unicode_test.pl DSN USERNAME PASSWORD
#
# NOTE: will attempt to create tables called fred and
#       fredĀ (LATIN CAPITAL LETTER A WITH MACRON)
#
# NOTE: there are multiple ways of doing named parameter markers in DBDs.
# some do:
#   insert into sometable (a_column) values(:fred);
#   bind_param(':fred', x);
# some do:
#   insert into sometable (a_column) values(:fred);
#   bind_param('fred', x);
# This script does the latter by default except for DBD::SQLite
#   - see unicode_param_markers and $param_marker_style where you can set the :
#
# DBD::ODBC currently fails:
# not ok 3 - unicode table found by qualified table_info
# not ok 6 - unicode column found by qualified column_info
# not ok 18 - bind parameter with unicode parameter marker
# All of which is documented in the DBD::ODBC pod. The first 2 are because
# table_info/column_info XS code uses char * instead of Perl scalars and
# the latter is because DBD::ODBC parses the SQL looking for placeholders
# and it does this as bytes not UTF-8 encoded strings.
#
use DBI qw(:sql_types data_diff neat);
use strict;
use warnings;
use Data::Dumper;
use utf8;
use Test::More;
use Test::More::UTF8;           # set utf8 mode on failure,out and todo handles
use Test::Exception;
use List::Util qw(first);
use Encode;

# unicode to use in tests for insert/select
# the simley ("\x{263A}") is useful because it always has a multibyte encoding
my $unicode_sample = "\x{263A}";

# short binary string that is invalid utf8 and includes nul bytes
my $binary_sample = "\xFF\x01\x00" x 20;

# This script tries to guess the types for unicode columns and binary columns
# using type_info_all - it may fail (e.g., if you don't support type_info_all
# or if your type_info_all does not return column types this script can
# identify as char/binary columns. If it does set the types below or change
# the possible SQL types in the calls to find_types below.
#
my $unicode_column_type;	# 'nvarchar for MS SQL Server'
my $blob_column_type;		# = 'image' for MS SQL Server
my $blob_bind_type;		# type to pass to bind_param for blobs
my $param_marker_style; # some DBDs need a column in front of param names in bind_param_call

# may be different in different SQL support
# if your DBD/db needs a different function to return the length in
# characters of a column redefine $length_fn in a DBD specific section later
# in this script
my $length_fn = 'length';

my $h = do_connect();

# output a load of data
my $driver = $h->{Driver}->{Name};
#note("Driver being used is $driver");
my $dbd="DBD::$h->{Driver}{Name}";
note("Driver " . $dbd,"-",$dbd->VERSION);
my $dbms_name = $h->get_info(17);
my $dbms_ver = $h->get_info(18);
my $driver_name = $h->get_info(6);
my $driver_ver = $h->get_info(7);
my $identifier_case = $h->get_info(28);
note("Using DBMS_NAME " . DBI::neat($dbms_name));
note("Using DBMS_VER " . DBI::neat($dbms_ver));
note("Using DRIVER_NAME " . DBI::neat($driver_name));
note("Using DRIVER_VER " . DBI::neat($driver_ver));
# annoyingly some databases take lowercase table names but create
# them uppercase (if unquoted) and so when you ask for a list
# of table they come back uppercase. Problem is pattern matching
# with unicode and /i is dodgy unless you've got a really recent Perl.
note("SQL_IDENTIFIER_CASE " . DBI::neat($identifier_case));
# dump entire env - some people might end up wanting to remove some of this
# so changed to specific env vars
#note("Environment:\n" . Dumper(\%ENV));
foreach my $env (qw(LANG LC_ NLS_)) {
    note(map {"$_ = $ENV{$_}\n"} grep(/$env/, keys %ENV));
}

# the following sets the "magic" unicode/utf8 flag for each DBD
# and sets the column types for DBDs which do not support type_info_all
# which is pretty much all of them
if ($driver eq 'SQLite') {
    # does not support type_info_all
    $blob_column_type = 'blob';
    $blob_bind_type = SQL_BLOB;
    $unicode_column_type = 'varchar';
    $h->{sqlite_unicode} = 1;
    $param_marker_style = ':';
}
elsif ($driver eq 'CSV') {
    # does not support column_info
    #####$blob_column_type = 'blob';
    #####$blob_bind_type = SQL_BLOB;
    #####$unicode_column_type = 'varchar';
    $h->{f_encoding} = 'UTF-8';
    $h->{f_ext} = '.csv/r';
    $length_fn = 'char_length';
}
elsif ($driver eq 'Pg') {
    $unicode_column_type = 'varchar';
}
elsif ($driver eq 'mysql') {
    # does not support type_info_all
    $h->{mysql_enable_utf8} = 1;
    #####$blob_column_type = 'blob';
    #####$blob_bind_type = SQL_BLOB;
    #####$unicode_column_type = 'varchar';
    $length_fn = 'char_length';
}
elsif ($driver eq 'ODBC') {
    # DBD::ODBC has type_info_all and column_info support
    $length_fn = 'len';
} elsif ($driver eq 'Unify') {
    $blob_column_type = 'binary';
    $unicode_column_type = 'char';	# or text
    $h->{ChopBlanks} = 1;       # Unify does not have varchar so we use char and ChopBlanks
    $h->{uni_unicode} = 1;	# Available in the upcoming 0.81
    $length_fn = 'undefined';	# I don't think Unify has a function like this
}


if (!defined($blob_column_type)) {
    ($blob_column_type, $blob_bind_type) =
	# -98 for DB2 which gets true blob column type
	find_type($h, [30, -98, SQL_LONGVARBINARY, SQL_BINARY, SQL_VARBINARY], length($binary_sample));
}
BAIL_OUT("Could not find an image/blob type in type_info_all - you will need to change this script to specify the type") if !defined($blob_column_type);
if (!defined($unicode_column_type)) {
    ($unicode_column_type) = find_type($h, [SQL_WVARCHAR, SQL_VARCHAR]);
}
BAIL_OUT("Could not find a unicode type in type_info_all - you will need to change this script to specify the type") if !defined($unicode_column_type);


unicode_data($h);

mixed_lob_unicode_data($h);

# Without disconnecting after the above test DBD::CSV gets upset
# refusing to create fred.csv as it already exists when it certainly
# does not exist.
#
disconnect($h);
$h = do_connect();

unicode_param_markers($h);

unicode_in_column_name($h);

unicode_in_table_name($h);

$h->disconnect;
unlink 'unitest_8.db' if $driver eq "SQLite";

done_testing;

exit 0;

# ======

sub do_connect {
    # eg unicode_test.pl "dbi:Pg(AutoCommit=0):host=example.com;port=6000;db=name" user pass
    my ($dsn, $user, $pass, %attr) = @ARGV;

    $user ||= $ENV{DBI_USER};
    $pass ||= $ENV{DBI_PASS};

    # A (semi)sane set of defaults
    my %dsn  = (
	csv	=> [ "dbi:CSV:",                  $user, $pass ],
	mysql	=> [ "dbi:mysql:database=test",   $user, $pass ],
	odbc	=> [ "dbi:ODBC:DSN=asus2",        $user, $pass ],
	oracle	=> [ "dbi:Oracle:host=xxx.easysoft.local;sid=devel", 'xxx', 'yyy' ],
	pg	=> [ "dbi:Pg:dbname=test",        $user, $pass ],
	sqlite	=> [ "dbi:SQLite:dbname=unitest_8.db", "", ""       ],
	unify	=> [ "dbi:Unify:",                $ENV{USCHEMA}, undef ],
	);

    # Either pass a fully qualified DSN or use the default shortcuts
    # eg unicode_test.pl CSV
    $dsn ||= "SQLite";
    $dsn =~ m/:/ or
        ($dsn, $user, $pass) = @{$dsn{lc $dsn} || die "No connect info\n"};

    if ($dsn =~ /^dbi:SQLite/) {
        # The pod for SQLite is confusing and has changed. Initially it said sqlite_unicode
        # must be set at connect time and cannot be set later on the connection handle
        # and now it says
        # "but this only works if the sqlite_unicode attribute is set before the first call to a perl collation sequence"
        # so we set it here
        $attr{sqlite_unicode} = 1;
    }
    my $h = DBI->connect($dsn, $user, $pass, { RaiseError => 1, %attr });
    return $h;
}

sub disconnect {
    my $h = shift;

    $h->disconnect;
}

sub drop_table {
    my ($h, $table) = @_;

    eval {
        local $h->{PrintError} = 0;
        $table = $h->quote_identifier ($table);
        my $s = $h->prepare(qq/drop table $table/);
        $s->execute;
    };
    $h->commit if $driver eq 'Unify';
    # DBD::CSV seems to get upset by the mixed_lob_unicode_data test
    # and fails to drop the table with:
    # Execution ERROR: utf8 "\x89" does not map to Unicode at /usr/lib/perl/5.10/IO/Handle.pm line 167.
    unlink 'fred.csv' if $driver eq 'CSV';
    #diag($@) if $@;
}

# create the named table with columns specified in $columns which is
# an arrayref with each element a hash of name and type
sub create_table {
    my ($h, $testmsg, $table, $columns) = @_;

    $table = $h->quote_identifier ($table);
    my $sql = qq/create table $table ( / .
	join(",", map {join " " => $h->quote_identifier ($_->{name}), $_->{type}} @$columns) . ')';

    return lives_ok {
        diag ($sql);
        my $s = $h->prepare($sql);
        $s->execute;
	$dbd eq "DBD::Unify" and $h->commit;
    } $testmsg;
}

sub unicode_in_table_name {
    my $h = shift;

    my $table = "fred\x{0100}";
    drop_table($h, $table);

    my $created =
	create_table($h, 'unicode table name supported', $table,
		     [{name => 'a', type => 'int'}]);
  SKIP: {
      skip "Failed to create unicode table name", 2 unless $created;

      find_table($h, $table);

      drop_table($h, $table);
    }
}

# NOTE: some DBs may uppercase table names
sub find_table {
    my ($h, $table) = @_;

    # won't find a match if the returned data is not utf8 decoded
    my $s = $h->table_info(undef, undef, undef, 'TABLE');
    my $r = $s->fetchall_arrayref;
    my $found = first { $_->[2] =~ /$table/i} @$r;
    ok($found, 'unicode table found in unqualified table_info');

    SKIP: {
          skip "table found via table_info", 1 if $found;

          $found = first { Encode::decode_utf8($_->[2]) =~ /$table/i} @$r;
          ok(!$found, "Table not found initially but when table name decoded it was found as $table");
    };
    my $found_some_utf8_tables;
    foreach ($r) {
        $found_some_utf8_tables++ if Encode::is_utf8($_->[2]);
    }
    note(($found_some_utf8_tables ? 'Found' : 'Did not find') ,
         ' tables with utf8 on');

    $s = $h->table_info(undef, undef, $table, 'TABLE');
    $r = $s->fetchall_arrayref;
    $found = first {$_->[2] =~ /$table/i} @$r;
    ok($found, 'unicode table found by qualified table_info');
    SKIP: {
          skip "table not found", 1 if !$found;

          ok(Encode::is_utf8($found->[2]),
             'utf8 flag set on unicode table name');
    }
}

sub find_column {
    my ($h, $table, $column) = @_;

    my $s = $h->column_info(undef, undef, $table, undef);
    if (!$s) {
	note("This driver does not seem to support column_info");
	note("Skipping this test");
	return;
    }
    my $r = $s->fetchall_arrayref;
    my $found = first {$_->[3] =~ /$column/i} @$r;
    ok($found, 'unicode column found in unqualified column_info');

    $s = $h->column_info(undef, undef, $table, $column);
    $r = $s->fetchall_arrayref;
    $found = first {$_->[3] =~ /$column/i} @$r;
    ok($found, 'unicode column found by qualified column_info');
}

sub unicode_in_column_name {
    my $h = shift;

    my $table = 'fred';
    my $column = "dave\x{0100}";

    drop_table($h, $table);

    my $created =
	create_table($h, 'unicode column name supported', $table,
		     [{name => $column, type => 'int'}]);
  SKIP: {
      skip "table with unicode column not created", 2 unless $created;

      find_column($h, $table, $column);

      drop_table($h, $table);
    };
}

sub unicode_data {
    my $h = shift;

    my $table = 'fred';
    my $column = 'a';

    drop_table($h, $table);
    create_table($h, 'table for unicode data', $table,
		 [{name => $column, type => $unicode_column_type . "(20)"}]);

    lives_ok {
        my $s = $h->prepare(qq/insert into $table ($column) values (?)/);
        $s->execute($unicode_sample);
    } 'insert unicode data into table';

    my $s = $h->prepare(qq/select $column from $table/);
    $s->execute;
    my $r = $s->fetchall_arrayref;
    is($r->[0][0], $unicode_sample, 'unicode data out = unicode data in, no where')
	or diag(data_diff($r->[0][0]), $unicode_sample);
    # probably redundant but does not hurt:
    is(length($r->[0][0]), length($unicode_sample), 'length of output data the same')
	or diag(data_diff($r->[0][0], $unicode_sample));

    # check db thinks the chr is 1 chr
    eval {			# we might not have the correct length fn
	$s = $h->prepare(qq/select $length_fn($column) from $table/);
	$s->execute;
    };
    if ($@) {
	note "!!db probably does not have length function!! - $@";
    } else {
	$r = $s->fetchall_arrayref;
	is($r->[0][0], length($unicode_sample), 'db length of unicode data correct');
    }

    $s = $h->prepare(qq/select $column from $table where $column = ?/);
    $s->execute($unicode_sample);
    $r = $s->fetchall_arrayref;
    is(scalar(@$r), 1, 'select unicode data via parameterised where');

    $s = $h->prepare(qq/select $column from $table where $column = / . $h->quote($unicode_sample));
    $s->execute;
    $r = $s->fetchall_arrayref;
    is(scalar(@$r), 1, 'select unicode data via inline where');

    drop_table($h, $table);
}

sub mixed_lob_unicode_data {
    my $h = shift;

    my $table = 'fred';
    my $column1 = 'a';
    my $column2 = 'b';

    drop_table($h, $table);
    create_table($h, 'table for unicode data', $table,
		 [{name => $column1, type => $unicode_column_type . "(20)"},
		  {name => $column2, type => $blob_column_type}]);

    lives_ok {
	my $s = $h->prepare(qq/insert into $table ($column1, $column2) values (?,?)/);
	$s->bind_param(1, $unicode_sample);
	$s->bind_param(2, $binary_sample, {TYPE => $blob_bind_type});
	#$s->execute($unicode_sample, $binary_sample);
	$s->execute;
    } 'insert unicode data and blob into table';

    # argh - have to set LongReadLen before doing a prepare in DBD::Oracle
    # because it picks a LongReadLen value when it describes the result-set
    $h->{LongReadLen} = length($binary_sample) * 2;
    my $s = $h->prepare(qq/select $column1, $column2 from $table/, {ora_pers_lob => 1});
    $s->execute;
    my $r = $s->fetchall_arrayref;
    is($r->[0][0], $unicode_sample, 'unicode data out = unicode data in, no where with blob');
    ok(!Encode::is_utf8($r->[0][1]), 'utf8 flag not set on blob data');
    ok($binary_sample eq $r->[0][1], 'retrieved blob = inserted blob');

    drop_table($h, $table);
}

sub unicode_param_markers {
    my $h = shift;

    my $table = 'fred';
    drop_table($h, $table);

    create_table($h, 'test table for unicode parameter markers', $table,
		 [{name => 'a', type => 'int'}]);

    my $param_marker = "fred\x{20ac}";
    lives_ok {
        my $s = $h->prepare(qq/insert into $table (a) values (:$param_marker)/);
        $s->bind_param($param_marker_style . $param_marker, 1);
        $s->execute;
    } 'bind parameter with unicode parameter marker';

    drop_table($h, $table);
}

sub find_type {
    my ($h, $types, $minsize) = @_;

    my $r = $h->type_info_all;

    #print Dumper($r);
    my $indexes = shift @$r;
    my $sql_type_idx = $indexes->{SQL_DATA_TYPE};
    my $type_name_idx = $indexes->{TYPE_NAME};
    my $column_size_idx = $indexes->{COLUMN_SIZE};

    if (!defined($sql_type_idx)) {
        note("type_info_all has no key for SQL_DATA_TYPE - falling back on DATA_TYPE");
        $sql_type_idx = $indexes->{DATA_TYPE};
    }
    if (!$column_size_idx) {
        note("type_info_all has no key for COLUMN_SIZE so not performing size checks");
    }

    BAIL_OUT("DBD does not seem to support type_info_all - you will need to edit this script to specify column types")
        if !$r || (scalar(@$r) == 0);

    foreach my $type (@$types) {
        foreach (@$r) {
            note("Found type $_->[$sql_type_idx] ($_->[$type_name_idx]) size=" . ($column_size_idx ? neat($_->[$column_size_idx]) : 'undef'));
            if ($_->[$sql_type_idx] eq $type) {
                if ((!defined($minsize)) || (!defined($column_size_idx)) ||
                        ($minsize && ($_->[$column_size_idx] > $minsize))) {
                    note("Found $type type which is $_->[$type_name_idx] and max size of " . ($column_size_idx ? $_->[$column_size_idx] : 'undef'));
                    return ($_->[$type_name_idx], $_->[$sql_type_idx]);
                } else {
                    note("$type type ($_->[$type_name_idx]) but the max length of $_->[$column_size_idx] is less than the required length $minsize");
                }
            }
        }
    }
    return; # no type found
}

# vim:ts=8:sw=4:et
