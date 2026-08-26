#!perl -w

use strict;
use Test::More;
use DBI;

if ($ENV{DBI_AUTOPROXY}) {
    plan skip_all => 'Async regression tests not valid with DBI_AUTOPROXY';
}

if ($DBI::PurePerl) {
    plan skip_all => 'Async regression tests are XS specific';
}

# Plan tests
plan tests => 6;

# -------------------------------------------------------------------------
# Item 1: Global Error Hijack
# -------------------------------------------------------------------------
subtest 'Item 1: Global Error Hijack' => sub {
    plan tests => 3;
    
    sub trial {
        my ($label, $errval) = @_;
        my $dbh = DBI->connect('dbi:ExampleP:', '', '', {
            PrintError => 0, RaiseError => 1,
        });
        my $died = 0;
        eval { $dbh->set_err($errval, "simulated driver failure"); 1 } or $died = 1;
        ok($died, "$label raised error");
    }

    trial('err = -1  (integer)', -1);
    trial('err = "-1" (string)', "-1");
    trial('err = 2    (control)',  2);
};

# -------------------------------------------------------------------------
# Item 3: Async capability gate on statement handles
# -------------------------------------------------------------------------
subtest 'Item 3: Async capability gate on sth' => sub {
    plan tests => 2;

    my $dbh = DBI->connect('dbi:ExampleP:', '', '', { PrintError => 0, RaiseError => 0 });
    my $sth = $dbh->prepare('SELECT name FROM .'); # ExampleP uses '.' as table name in some examples, or just valid syntax
    
    my $dbh_accepted = eval { $dbh->{Async} = 1; 1 };
    ok(!$dbh_accepted, "dbh Async assignment croaked on incompatible driver");
    
    my $sth_accepted = eval { $sth->{Async} = 1; 1 };
    ok(!$sth_accepted, "sth Async assignment croaked on incompatible driver");
};

# -------------------------------------------------------------------------
# Item 4: Fork guard in DESTROY
# -------------------------------------------------------------------------
subtest 'Item 4: Fork guard in DESTROY' => sub {
    plan tests => 1;

    my $dbh = DBI->connect('dbi:MockAsync:', '', '', { PrintError => 0, RaiseError => 0 });
    $dbh->{Async} = 1;
    $dbh->{AutoInactiveDestroy} = 1;
    
    my $pid = fork();
    if (defined $pid && $pid == 0) {
        # Child process
        # We just exit. DESTROY will be called during global destruction.
        # It should NOT croak "PID mismatch".
        exit 0;
    }
    
    if (defined $pid) {
        waitpid($pid, 0);
        is($?, 0, "Child exited cleanly without PID mismatch croak in DESTROY");
    } else {
        skip "Fork failed", 1;
    }
};

# -------------------------------------------------------------------------
# Item 5: fetch_async_row recursion
# -------------------------------------------------------------------------
subtest 'Item 5: fetch_async_row recursion' => sub {
    plan tests => 2;

    {
        package DBD::Recurse::st;
        our @ISA = ('DBD::_::st');
        sub fetchrow_arrayref { return $_[0]->fetch_async_row }
    }

    my $dbh = DBI->connect('dbi:ExampleP:', '', '', { PrintError => 0, RaiseError => 0 });
    my $sth = $dbh->prepare('SELECT name FROM .');
    $sth->execute();
    
    my $inner = tied(%$sth) || $sth;
    my $old_class = ref($inner);
    
    # Hijack the implementor class
    $inner->{ImplementorClass} = 'DBD::Recurse::st';
    bless $inner, 'DBD::Recurse::st';
    
    my $died = 0;
    my $err_msg = '';
    eval {
        local $SIG{ALRM} = sub { die "TIMEOUT\n" };
        alarm 5; # Timeout just in case guard fails
        $sth->fetch_async_row();
        alarm 0;
        1;
    } or do {
        $died = 1;
        $err_msg = $@;
    };
    
    ok($died, "fetch_async_row recursion guarded (died/croaked)");
    like($err_msg, qr/Deep recursion/, "Expected deep recursion error message");

    # Restore
    bless $inner, $old_class;
};

# -------------------------------------------------------------------------
# Extra 1: List Context Guards on fetch_async_row/hashref
# -------------------------------------------------------------------------
subtest 'Extra 1: List Context Guards' => sub {
    plan tests => 2;

    my $dbh = DBI->connect('dbi:ExampleP:', '', '', { PrintError => 0, RaiseError => 0 });
    my $sth = $dbh->prepare('SELECT name FROM .');
    $sth->execute();

    eval {
        my @list = $sth->fetch_async_row();
    };
    like($@, qr/list context/i, "fetch_async_row forbids list context");

    eval {
        my @list = $sth->fetch_async_hashref();
    };
    like($@, qr/list-context|list context/i, "fetch_async_hashref forbids list context");
};

# -------------------------------------------------------------------------
# Extra 2: execute_for_fetch barrier under Async
# -------------------------------------------------------------------------
subtest 'Extra 2: execute_for_fetch barrier' => sub {
    # Plan removed to allow dynamic or conditional tests

    # Need MockAsync or similar that supports Async flag
    my $dbh = DBI->connect('dbi:MockAsync:', '', '', { PrintError => 0, RaiseError => 0 });
    
    # Set Async on dbh FIRST so it propagates to prepared statements
    $dbh->{Async} = 1;
    
    my $sth = $dbh->prepare('INSERT INTO fruit VALUES (?,?)');
    
    is($sth->{Async}, 1, "sth inherited Async flag");
    
    my $rc = eval {
        $sth->execute_for_fetch(sub { return undef });
    };
    my $eval_err = $@;
    
    if ($eval_err) {
        like($eval_err, qr/execute_for_fetch is not supported/, "execute_for_fetch croaked under Async => 1");
    } else {
        ok(!$rc, "execute_for_fetch returned false/undef under Async => 1");
        like($sth->errstr // '', qr/execute_for_fetch is not supported/, "Error string set correctly");
    }
};

1;
