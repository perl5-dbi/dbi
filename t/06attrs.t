#!perl -w

use strict;
use Test;
use DBI;

BEGIN { plan tests => 126 }

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
ok( $dbh->{RaiseError} );
ok(!$dbh->{ShowErrorStatement} );
ok(!$dbh->{ChopBlanks} );
ok(!$dbh->{LongTruncOk} );
ok(!$dbh->{TaintIn} );
ok(!$dbh->{TaintOut} );
ok(!$dbh->{Taint} );

#	other attr
ok( $dbh->{Kids}, 0 )		unless $DBI::PurePerl && ok(1);
ok( $dbh->{ActiveKids}, 0 )	unless $DBI::PurePerl && ok(1);
ok( ! defined $dbh->{CachedKids} );
ok( ! defined $dbh->{HandleError} );
ok( $dbh->{TraceLevel}, $DBI::dbi_debug );
ok( $dbh->{FetchHashKeyName}, 'NAME', );
ok( $dbh->{LongReadLen}, 80 );
ok( ! defined $dbh->{Profile} );
ok( $dbh->{Name}, 'dummy' );	# fails for Multiplex
ok( ! defined $dbh->{Statement} );
ok( ! defined $dbh->{RowCacheSize} );

# Raise an error.
eval { $dbh->do('select foo from foo') };
ok( my $err = $@ );
ok( $err =~ /^DBD::(ExampleP|Multiplex)::db do failed: Unknown field names: foo/ ) or print "got: $err\n";
ok( $dbh->err );
ok( my $errstr = $dbh->errstr);
ok( $errstr =~ /^Unknown field names: foo\b/ ) or print "got: $errstr\n";
ok( $dbh->state, 'S1000' );

# ------ Test the driver handle attributes.

ok( my $drh = $dbh->{Driver} );
ok( UNIVERSAL::isa($drh, 'DBI::dr') );
ok( $dbh->err );

# error in $drh same as $dbh because Err/Errstr/State are set at drh level
#ok( $drh->err );
#ok( $drh->errstr, 'Unknown field names: foo' );
#ok( $drh->state, 'S1000' );
ok(1); ok(1); ok(1);

ok( $drh->{Warn} );
ok( $drh->{Active} );
ok( $drh->{AutoCommit} );
ok(!$drh->{CompatMode} );
ok(!$drh->{InactiveDestroy} );
ok(!$drh->{PrintError} );
ok(!$drh->{RaiseError} );
ok(!$drh->{ShowErrorStatement} );
ok(!$drh->{ChopBlanks} );
ok(!$drh->{LongTruncOk} );
ok(!$drh->{TaintIn} );
ok(!$drh->{TaintOut} );
ok(!$drh->{Taint} );

unless ($DBI::PurePerl or $dbh->{mx_handle_list}) {
ok( $drh->{Kids}, 1 );
ok( $drh->{ActiveKids}, 1 );
}
else { ok(1); ok(1); }
ok( ! defined $drh->{CachedKids} );
ok( ! defined $drh->{HandleError} );
ok( $drh->{TraceLevel}, 0 );
ok( $drh->{FetchHashKeyName}, 'NAME', );
ok( ! defined $drh->{Profile} );
ok( $drh->{LongReadLen}, 80 );
ok( $drh->{Name}, 'ExampleP' );

# ------ Test the statement handle attributes.

# Create a statement handle.
(ok my $sth = $dbh->prepare("select ctime, name from foo") );

# Trigger an exception.
eval { $sth->execute };
ok( $err = $@ );
# we don't check actual opendir error msg because of locale differences
ok( $err =~ /^DBD::(ExampleP|Multiplex)::st execute failed: opendir\(foo\): /i ) or print "\$\@=$err\n";

# Test all of the statement handle attributes.
ok( $sth->errstr =~ /^opendir\(foo\): / ) or print "errstr: ".$sth->errstr."\n";
ok( $sth->state, 'S1000' );

# booleans
ok( $sth->{Warn} );
ok(!$sth->{Active} );
ok(!$sth->{CompatMode} );
ok(!$sth->{InactiveDestroy} );
ok(!$sth->{PrintError} );
ok( $sth->{RaiseError} );
ok(!$sth->{ShowErrorStatement} );
ok(!$sth->{ChopBlanks} );
ok(!$sth->{LongTruncOk} );
ok(!$sth->{TaintIn} );
ok(!$sth->{TaintOut} );
ok(!$sth->{Taint} );

# common attr
ok( $sth->{Kids}, 0 )		unless $DBI::PurePerl && ok(1);
ok( $sth->{ActiveKids}, 0 )	unless $DBI::PurePerl && ok(1);
ok( ! defined $sth->{CachedKids} );
ok( ! defined $sth->{HandleError} );
ok( $sth->{TraceLevel}, $DBI::dbi_debug );
ok( $sth->{FetchHashKeyName}, 'NAME', );
ok( ! defined $sth->{Profile} );
ok( $sth->{LongReadLen}, 80 );
ok( ! defined $sth->{Profile} );

# sth specific attr
ok( ! defined $sth->{CursorName} );

ok( $sth->{NUM_OF_FIELDS}, 2 );
ok( $sth->{NUM_OF_PARAMS}, 0 );
ok( my $name = $sth->{NAME} );
ok( @$name, 2 );
ok( $name->[0] eq 'ctime' );
ok( $name->[1] eq 'name' );
ok( my $name_lc = $sth->{NAME_lc} );
ok( $name_lc->[0] eq 'ctime' );
ok( $name_lc->[1] eq 'name' );
ok( my $name_uc = $sth->{NAME_uc} );
ok( $name_uc->[0] eq 'CTIME' );
ok( $name_uc->[1] eq 'NAME' );
ok( my $nhash = $sth->{NAME_hash} );
ok( keys %$nhash, 2 );
ok( $nhash->{ctime}, 0 );
ok( $nhash->{name}, 1 );
ok( my $nhash_lc = $sth->{NAME_lc_hash} );
ok( $nhash_lc->{ctime}, 0 );
ok( $nhash_lc->{name}, 1 );
ok( my $nhash_uc = $sth->{NAME_uc_hash} );
ok( $nhash_uc->{CTIME}, 0 );
ok( $nhash_uc->{NAME}, 1 );
ok( my $type = $sth->{TYPE} );
ok( @$type, 2 );
ok( $type->[0], 4 );
ok( $type->[1], 12 );
ok( my $null = $sth->{NULLABLE} );
ok( @$null, 2 );
ok( $null->[0], 0 );
ok( $null->[1], 0 );

# Should these work? They don't.
ok( my $prec = $sth->{PRECISION} );
ok( $prec->[0], 10 );
ok( $prec->[1], 1024 );
ok( my $scale = $sth->{SCALE} );
ok( $scale->[0], 0 );
ok( $scale->[1], 0 );


ok( my $params = $sth->{ParamValues} );
ok( $params->{1}, 'foo' );
ok( $sth->{Statement}, "select ctime, name from foo" );
ok( ! defined $sth->{RowsInCache} );

# end
