#!perl -w

use strict;
use Test::More;
use DBI;

BEGIN { plan tests => 143 }

$|=1;

# Connect to the example driver.
ok( my $dbh = DBI->connect('dbi:ExampleP:dummy', '', '',
                           { PrintError => 0,
                             RaiseError => 1,
                           })
);

# Clean up when we're done.
END { $dbh->disconnect if $dbh };

# ------ Check the database handle attributes.

#	bit flag attr
ok( $dbh->{Warn} );
ok( $dbh->{Active} );
ok( $dbh->{AutoCommit} );
ok(!$dbh->{CompatMode} );
ok(!$dbh->{InactiveDestroy} );
ok(!$dbh->{PrintError} );
ok( $dbh->{PrintWarn} );	# true because of perl -w above
ok( $dbh->{RaiseError} );
ok(!$dbh->{ShowErrorStatement} );
ok(!$dbh->{ChopBlanks} );
ok(!$dbh->{LongTruncOk} );
ok(!$dbh->{TaintIn} );
ok(!$dbh->{TaintOut} );
ok(!$dbh->{Taint} );
ok(!$dbh->{Executed} );

#	other attr
is( $dbh->{ErrCount}, 0 );
is( $dbh->{Kids}, 0 )		unless $DBI::PurePerl && ok(1);
is( $dbh->{ActiveKids}, 0 )	unless $DBI::PurePerl && ok(1);
ok( ! defined $dbh->{CachedKids} );
ok( ! defined $dbh->{HandleError} );
is( $dbh->{TraceLevel}, $DBI::dbi_debug & 0xF);
is( $dbh->{FetchHashKeyName}, 'NAME', );
is( $dbh->{LongReadLen}, 80 );
ok( ! defined $dbh->{Profile} );
is( $dbh->{Name}, 'dummy' );	# fails for Multiplex
ok( ! defined $dbh->{Statement} );
ok( ! defined $dbh->{RowCacheSize} );

# Raise an error.
eval { $dbh->do('select foo from foo') };
ok( my $err = $@ );
ok( $err =~ /^DBD::(ExampleP|Multiplex)::db do failed: Unknown field names: foo/ ) or print "got: $err\n";
ok( $dbh->err );
ok( my $errstr = $dbh->errstr);
ok( $errstr =~ /^Unknown field names: foo\b/ ) or print "got: $errstr\n";
is( $dbh->state, 'S1000' );

ok( $dbh->{Executed} );  	# even though it failed
$dbh->{Executed} = 0;   	# reset(able)
ok(!$dbh->{Executed} );  	# reset
is( $dbh->{ErrCount}, 1 );

# ------ Test the driver handle attributes.

ok( my $drh = $dbh->{Driver} );
ok( UNIVERSAL::isa($drh, 'DBI::dr') );
ok( $dbh->err );

is( $drh->{ErrCount}, 0 );

ok( $drh->{Warn} );
ok( $drh->{Active} );
ok( $drh->{AutoCommit} );
ok(!$drh->{CompatMode} );
ok(!$drh->{InactiveDestroy} );
ok(!$drh->{PrintError} );
ok( $drh->{PrintWarn} );	# true because of perl -w above
ok(!$drh->{RaiseError} );
ok(!$drh->{ShowErrorStatement} );
ok(!$drh->{ChopBlanks} );
ok(!$drh->{LongTruncOk} );
ok(!$drh->{TaintIn} );
ok(!$drh->{TaintOut} );
ok(!$drh->{Taint} );
ok( $drh->{Executed} ) unless $DBI::PurePerl && ok(1); # due to the do() above

unless ($DBI::PurePerl or $dbh->{mx_handle_list}) {
is( $drh->{Kids}, 1 );
is( $drh->{ActiveKids}, 1 );
}
else { ok(1); ok(1); }
ok( ! defined $drh->{CachedKids} );
ok( ! defined $drh->{HandleError} );
is( $drh->{TraceLevel}, $DBI::dbi_debug & 0xF );
is( $drh->{FetchHashKeyName}, 'NAME', );
ok( ! defined $drh->{Profile} );
is( $drh->{LongReadLen}, 80 );
is( $drh->{Name}, 'ExampleP' );

# ------ Test the statement handle attributes.

# Create a statement handle.
(ok my $sth = $dbh->prepare("select ctime, name from foo") );
ok( !$sth->{Executed} );
ok( !$dbh->{Executed} );
is( $sth->{ErrCount}, 0 );

# Trigger an exception.
eval { $sth->execute };
ok( $err = $@ );
# we don't check actual opendir error msg because of locale differences
ok( $err =~ /^DBD::(ExampleP|Multiplex)::st execute failed: opendir\(foo\): /i ) or print "\$\@=$err\n";

# Test all of the statement handle attributes.
ok( $sth->errstr =~ /^opendir\(foo\): / ) or print "errstr: ".$sth->errstr."\n";
is( $sth->state, 'S1000' );
ok( $sth->{Executed} );	# even though it failed
ok( $dbh->{Executed} );	# due to $sth->prepare, even though it failed

is( $sth->{ErrCount}, 1 );
eval { $sth->{ErrCount} = 42 };
ok($@);
ok($@ =~ m/STORE failed:/);
is( $sth->{ErrCount}, 42 );
$sth->{ErrCount} = 0;
is( $sth->{ErrCount}, 0 );

# booleans
ok( $sth->{Warn} );
ok(!$sth->{Active} );
ok(!$sth->{CompatMode} );
ok(!$sth->{InactiveDestroy} );
ok(!$sth->{PrintError} );
ok( $sth->{PrintWarn} );
ok( $sth->{RaiseError} );
ok(!$sth->{ShowErrorStatement} );
ok(!$sth->{ChopBlanks} );
ok(!$sth->{LongTruncOk} );
ok(!$sth->{TaintIn} );
ok(!$sth->{TaintOut} );
ok(!$sth->{Taint} );

# common attr
is( $sth->{Kids}, 0 )		unless $DBI::PurePerl && ok(1);
is( $sth->{ActiveKids}, 0 )	unless $DBI::PurePerl && ok(1);
ok( ! defined $sth->{CachedKids} );
ok( ! defined $sth->{HandleError} );
is( $sth->{TraceLevel}, $DBI::dbi_debug & 0xF);
is( $sth->{FetchHashKeyName}, 'NAME', );
ok( ! defined $sth->{Profile} );
is( $sth->{LongReadLen}, 80 );
ok( ! defined $sth->{Profile} );

# sth specific attr
ok( ! defined $sth->{CursorName} );

is( $sth->{NUM_OF_FIELDS}, 2 );
is( $sth->{NUM_OF_PARAMS}, 0 );
ok( my $name = $sth->{NAME} );
is( @$name, 2 );
ok( $name->[0] eq 'ctime' );
ok( $name->[1] eq 'name' );
ok( my $name_lc = $sth->{NAME_lc} );
ok( $name_lc->[0] eq 'ctime' );
ok( $name_lc->[1] eq 'name' );
ok( my $name_uc = $sth->{NAME_uc} );
ok( $name_uc->[0] eq 'CTIME' );
ok( $name_uc->[1] eq 'NAME' );
ok( my $nhash = $sth->{NAME_hash} );
is( keys %$nhash, 2 );
is( $nhash->{ctime}, 0 );
is( $nhash->{name}, 1 );
ok( my $nhash_lc = $sth->{NAME_lc_hash} );
is( $nhash_lc->{ctime}, 0 );
is( $nhash_lc->{name}, 1 );
ok( my $nhash_uc = $sth->{NAME_uc_hash} );
is( $nhash_uc->{CTIME}, 0 );
is( $nhash_uc->{NAME}, 1 );
ok( my $type = $sth->{TYPE} );
is( @$type, 2 );
is( $type->[0], 4 );
is( $type->[1], 12 );
ok( my $null = $sth->{NULLABLE} );
is( @$null, 2 );
is( $null->[0], 0 );
is( $null->[1], 0 );

# Should these work? They don't.
ok( my $prec = $sth->{PRECISION} );
is( $prec->[0], 10 );
is( $prec->[1], 1024 );
ok( my $scale = $sth->{SCALE} );
is( $scale->[0], 0 );
is( $scale->[1], 0 );

ok( my $params = $sth->{ParamValues} );
is( $params->{1}, 'foo' );
is( $sth->{Statement}, "select ctime, name from foo" );
ok( ! defined $sth->{RowsInCache} );

# $h->{TraceLevel} tests are in t/09trace.t

1;
# end
