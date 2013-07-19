#!perl -w

use strict;

use Test::More tests => 20;

BEGIN{ use_ok( 'DBI' ) }

my $expect_active;

## main Test Driver Package
{
    package DBD::Test;

    use strict;
    use warnings;

    my $drh = undef;

    sub driver {
        return $drh if $drh;
        my ($class, $attr) = @_;
        $class = "${class}::dr";
        ($drh) = DBI::_new_drh($class, {
            Name    => 'Test',
            Version => '1.0',
        }, 77 );
        return $drh;
    }

    sub CLONE { undef $drh }
}

## Test Driver
{
    package DBD::Test::dr;

    use warnings;
    use Test::More;

    sub connect { # normally overridden, but a handy default
        my($drh, $dbname, $user, $auth, $attrs)= @_;
        my ($outer, $dbh) = DBI::_new_dbh($drh);
        $dbh->STORE(Active => 1);
        $dbh->STORE(AutoCommit => 1);
        $dbh->STORE( $_ => $attrs->{$_}) for keys %$attrs;
        return $outer;
    }

    $DBD::Test::dr::imp_data_size = 0;
    cmp_ok($DBD::Test::dr::imp_data_size, '==', 0, '... check DBD::Test::dr::imp_data_size to avoid typo');
}

## Test db package
{
    package DBD::Test::db;

    use strict;
    use warnings;
    use Test::More;

    $DBD::Test::db::imp_data_size = 0;
    cmp_ok($DBD::Test::db::imp_data_size, '==', 0, '... check DBD::Test::db::imp_data_size to avoid typo');

    sub STORE {
        my ($dbh, $attrib, $value) = @_;
        # would normally validate and only store known attributes
        # else pass up to DBI to handle
        if ($attrib eq 'AutoCommit') {
            # convert AutoCommit values to magic ones to let DBI
            # know that the driver has 'handled' the AutoCommit attribute
            $value = ($value) ? -901 : -900;
        }
        return $dbh->{$attrib} = $value if $attrib =~ /^examplep_/;
        return $dbh->SUPER::STORE($attrib, $value);
    }

    sub DESTROY {
        if ($expect_active < 0) { # inside child
            my $self = shift;
            exit ($self->FETCH('Active') || 0) unless $^O eq 'MSWin32';

            # On Win32, the forked child is actually a thread. So don't exit,
            # and report failure directly.
            fail 'Child should be inactive on DESTROY' if $self->FETCH('Active');
        } else {
            return $expect_active
                ? ok( shift->FETCH('Active'), 'Should be active in DESTROY')
                : ok( !shift->FETCH('Active'), 'Should not be active in DESTROY');
        }
    }
}

my $dsn = 'dbi:ExampleP:dummy';

$INC{'DBD/Test.pm'} = 'dummy';  # required to fool DBI->install_driver()
ok my $drh = DBI->install_driver('Test'), 'Install test driver';

NOSETTING: {
    # Try defaults.
    ok my $dbh = $drh->connect, 'Connect to test driver';
    ok $dbh->{Active}, 'Should start active';
    $expect_active = 1;
}

IAD: {
    # Try InactiveDestroy.
    ok my $dbh = $drh->connect($dsn, '', '', { InactiveDestroy => 1 }),
        'Create with ActiveDestroy';
    ok $dbh->{InactiveDestroy}, 'InactiveDestroy should be set';
    ok $dbh->{Active}, 'Should start active';
    $expect_active = 0;
}

AIAD: {
    # Try AutoInactiveDestroy.
    ok my $dbh = $drh->connect($dsn, '', '', { AutoInactiveDestroy => 1 }),
        'Create with AutoInactiveDestroy';
    ok $dbh->{AutoInactiveDestroy}, 'InactiveDestroy should be set';
    ok $dbh->{Active}, 'Should start active';
    $expect_active = 1;
}

FORK: {
    # Try AutoInactiveDestroy and fork.
    ok my $dbh = $drh->connect($dsn, '', '', { AutoInactiveDestroy => 1 }),
        'Create with AutoInactiveDestroy again';
    ok $dbh->{AutoInactiveDestroy}, 'InactiveDestroy should be set';
    ok $dbh->{Active}, 'Should start active';

    my $pid = eval { fork() };
    if (not defined $pid) {
        chomp $@;
        my $msg = "AutoInactiveDestroy destroy test skipped";
        diag "$msg because $@\n";
        pass $msg; # in lieu of the child status test
    }
    elsif ($pid) {
        # parent.
        $expect_active = 1;
        wait;
        ok $? == 0, 'Child should be inactive on DESTROY';
    } else {
        # child.
        $expect_active = -1;
    }
}
