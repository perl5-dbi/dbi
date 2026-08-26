#!perl -w

use strict;
use Test::More tests => 26;
use DBI qw(:async);

# 1. Constant Export
cmp_ok(DBI_E_WOULDBLOCK, '==', -1, 'DBI_E_WOULDBLOCK is exported as -1');

# Connect to standard test driver (DBD::ExampleP)
my $dbh = DBI->connect('dbi:ExampleP:', '', '', { PrintError => 0, RaiseError => 0 });
ok($dbh, 'Connected to ExampleP handle');

# 2. Default Attribute States
cmp_ok($dbh->{Async}, '==', 0, 'Async defaults to 0');
cmp_ok($dbh->{AsyncWantRead}, '==', 0, 'AsyncWantRead defaults to 0');
cmp_ok($dbh->{AsyncWantWrite}, '==', 0, 'AsyncWantWrite defaults to 0');
cmp_ok($dbh->{AsyncMultiplex}, '==', 0, 'AsyncMultiplex defaults to 0');
cmp_ok($dbh->{AsyncBufferWrites}, '==', 0, 'AsyncBufferWrites defaults to 0');

SKIP: {
    skip 'Setting attributes on proxy handle is not supported under Gofer', 14 if $ENV{DBI_AUTOPROXY};

    # 3. Setting Volatile & Flag Attributes
    $dbh->{AsyncWantRead} = 1;
    cmp_ok($dbh->{AsyncWantRead}, '==', 1, 'AsyncWantRead set to 1');
    $dbh->{AsyncWantRead} = 0;
    cmp_ok($dbh->{AsyncWantRead}, '==', 0, 'AsyncWantRead set back to 0');

    $dbh->{AsyncWantWrite} = 1;
    cmp_ok($dbh->{AsyncWantWrite}, '==', 1, 'AsyncWantWrite set to 1');
    $dbh->{AsyncWantWrite} = 0;
    cmp_ok($dbh->{AsyncWantWrite}, '==', 0, 'AsyncWantWrite set back to 0');

    $dbh->{AsyncMultiplex} = 1;
    cmp_ok($dbh->{AsyncMultiplex}, '==', 1, 'AsyncMultiplex set to 1');
    $dbh->{AsyncMultiplex} = 0;

    $dbh->{AsyncBufferWrites} = 1;
    cmp_ok($dbh->{AsyncBufferWrites}, '==', 1, 'AsyncBufferWrites set to 1');
    $dbh->{AsyncBufferWrites} = 0;

    # 4. Custom Complex Attributes (Watcher & ErrorDetails)
    my $watcher = { fd => 5, events => 1 };
    $dbh->{AsyncWatcher} = $watcher;
    is_deeply($dbh->{AsyncWatcher}, $watcher, 'AsyncWatcher stores and retrieves hashref');

    my $err_details = { code => 500, message => 'Timeout' };
    $dbh->{AsyncErrorDetails} = $err_details;
    is_deeply($dbh->{AsyncErrorDetails}, $err_details, 'AsyncErrorDetails stores and retrieves hashref');

    # 5. Capability Validation Failure on Driver Lacking async_read_ready
    eval { $dbh->{Async} = 1; };
    like($@, qr/Driver does not support/, 'Setting Async => 1 croaks on capability-less driver');

    # 6. Valid Capability Activation via Temporary Class Blessing
    {
        no warnings 'redefine', 'once';
        @DBD::Sponge::db::ISA = ('DBD::_::db');
        local *DBD::Sponge::db::async_read_ready = sub {
            my ($h) = @_;
            $h->STORE('AsyncWantRead', 0);
            return 1;
        };

        my $inner = tied(%$dbh) || $dbh;
        my $old_class = ref($inner);
        my $old_imp = $inner->{ImplementorClass};
        $inner->{ImplementorClass} = 'DBD::Sponge::db';
        bless $inner, 'DBD::Sponge::db';
        eval { $dbh->{Async} = 1; };
        ok(!$@, 'Setting Async => 1 succeeds on driver defining async_read_ready');
        cmp_ok($dbh->{Async}, '==', 1, 'Async flag is active');

        # 7. Concurrency Lock Check (AsyncWantRead => 1 without AsyncMultiplex)
        $dbh->{AsyncWantRead} = 1;
        eval { $dbh->commit(); };
        like($@, qr/Synchronous concurrency violation/, 'Commit croaks when handle is busy with AsyncWantRead active');

        # Allow polling methods while busy
        eval { $dbh->async_read_ready(); };
        ok(!$@, 'async_read_ready polling method permitted while AsyncWantRead is active');
        $dbh->{AsyncWantRead} = 0;
        cmp_ok($dbh->{AsyncWantRead}, '==', 0, 'AsyncWantRead cleared');

        $dbh->{Async} = 0;
        $inner->{ImplementorClass} = $old_imp if defined $old_imp;
        bless $inner, $old_class;
    }
}

# 8. Fallback Method Stubs on Standard Handles
my $rc = $dbh->async_read_ready();
is($rc, undef, 'async_read_ready fallback returns undef on capability-less handle');
is($dbh->state, 'IM001', 'async_read_ready fallback sets SQLSTATE IM001');

# 9. Statement Handle Inheritance and execute_for_fetch Guard
my $sth = $dbh->prepare('SELECT name FROM table');
ok($sth, 'Prepared statement handle');
cmp_ok($sth->{AsyncWantRead}, '==', 0, 'Statement handle does not inherit volatile AsyncWantRead from dbh');

eval { $sth->execute_for_fetch(sub { return undef }); };
ok(!$@, 'execute_for_fetch works when Async => 0');
