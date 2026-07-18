#!perl -w

use strict;
use Test::More;
if ($ENV{DBI_AUTOPROXY}) {
    plan skip_all => 'Gofer DBI_AUTOPROXY';
} else {
    plan tests => 22;
}
use lib 't/lib';
use DBI qw(:async);

# 1. Driver Loading & Connection
my $dbh = DBI->connect('dbi:MockAsync:', '', '', { PrintError => 0, RaiseError => 0 });
ok($dbh, 'Connected to MockAsync driver');

# 2. Capability Activation
eval { $dbh->{Async} = 1; };
ok(!$@, 'Setting Async => 1 succeeds on DBD::MockAsync');
cmp_ok($dbh->{Async}, '==', 1, 'Async flag is active');

# 3. Watcher Callback Registration
my %watcher_events;
my $watcher = {
    on_add => sub {
        my ($fd, $mode) = @_;
        push @{ $watcher_events{add} }, { fd => $fd, mode => $mode };
    },
    on_remove => sub {
        my ($fd) = @_;
        push @{ $watcher_events{remove} }, { fd => $fd };
    },
};

$dbh->{AsyncWatcher} = $watcher;
is_deeply($dbh->{AsyncWatcher}, $watcher, 'AsyncWatcher attribute configured');

# 4. Error Suppression Setup (RaiseError & PrintError active)
$dbh->{RaiseError} = 1;
$dbh->{PrintError} = 1;

# 5. Non-blocking Execute Yield
my $sth = $dbh->prepare('SELECT id, name FROM spanner_table');
ok($sth, 'Prepared statement handle');

my $rv;
eval { $rv = $sth->execute(); };
ok(!$@, 'Non-blocking execute() does not croak under RaiseError => 1');
is($rv, '0E0', 'execute() returns 0E0 on async yield');
cmp_ok($dbh->{AsyncWantRead}, '==', 1, 'AsyncWantRead flag activated on handle');
ok(DBI::is_wouldblock($sth->err), 'sth->err evaluates to DBI_E_WOULDBLOCK');

# 6. Watcher Notification Verification
ok($watcher_events{add}, 'on_add watcher callback triggered');
cmp_ok(scalar @{ $watcher_events{add} }, '==', 1, 'Single add watcher event emitted');
is($watcher_events{add}->[0]->{mode}, 'r', 'Watcher requested read mode');

# 7. Non-Multiplex Concurrency Lock Guard
eval {
    my $sth2 = $dbh->prepare('SELECT 2');
    $sth2->execute();
};
like($@, qr/Synchronous concurrency violation/, 'Concurrent operation croaks on busy non-multiplex handle');

# 8. Simulated Network Ingestion via Non-blocking Pipe Writes
my $inner = tied(%$dbh) || $dbh;
my $pipe_w = $inner->{mock_pipe_write};
ok($pipe_w, 'Retrieved pipe write handle');

$pipe_w->syswrite("101,Spanner\n");

# 9. Driver Polling Hook Processing
my $poll_rc = $dbh->async_read_ready();
cmp_ok($poll_rc, '==', 1, 'async_read_ready() returns 1 (progress made)');
cmp_ok($dbh->{AsyncWantRead}, '==', 0, 'AsyncWantRead flag cleared');

ok($watcher_events{remove}, 'on_remove watcher callback triggered');
cmp_ok(scalar @{ $watcher_events{remove} }, '==', 1, 'Single remove watcher event emitted');

# 10. Non-blocking Row Consumption
my $row = $sth->fetch_async_row();
ok($row, 'fetch_async_row() returned row arrayref');
is($row->[0], '101', 'First column matches mock pipe payload');
is($row->[1], 'Spanner', 'Second column matches mock pipe payload');

# 11. EOF Verification
my $eof_row = $sth->fetch_async_row();
is($eof_row, undef, 'fetch_async_row() returns undef on EOF');

$dbh->{Async} = 0;
$dbh->disconnect();

1;
