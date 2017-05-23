#!perl -w
# vim:ts=8:sw=4

use strict;

use Test::More;
use DBI;

BEGIN {
        plan skip_all => '$h->{Callbacks} attribute not supported for DBI::PurePerl'
                if $DBI::PurePerl && $DBI::PurePerl; # doubled to avoid typo warning
}

$| = 1;
my $dsn = "dbi:ExampleP:drv_foo=drv_bar";
my %called;

ok my $dbh = DBI->connect($dsn, '', ''), "Create dbh";

is $dbh->{Callbacks}, undef, "Callbacks initially undef";
ok $dbh->{Callbacks} = my $cb = { };
is ref $dbh->{Callbacks}, 'HASH', "Callbacks can be set to a hash ref";
is $dbh->{Callbacks}, $cb, "Callbacks set to same hash ref";

$dbh->{Callbacks} = undef;
is $dbh->{Callbacks}, undef, "Callbacks set to undef again";

ok $dbh->{Callbacks} = {
    ping => sub {
	my $m = $_;
	is $m, 'ping', '$m holds method name';
	is $_, 'ping', '$_ holds method name (not stolen)';
	is @_, 1, '@_ holds 1 values';
	is ref $_[0], 'DBI::db', 'first is $dbh';
        ok tied(%{$_[0]}), '$dbh is tied (outer) handle'
            or DBI::dump_handle($_[0], 'tied?', 10);
	$called{$_}++;
	return;
    },
    quote_identifier => sub {
	is @_, 4, '@_ holds 4 values';
	my $dbh = shift;
	is ref $dbh, 'DBI::db', 'first is $dbh';
	is $_[0], 'foo';
	is $_[1], 'bar';
	is $_[2], undef;
	$_[2] = { baz => 1 };
	$called{$_}++;
	return (1,2,3);	# return something - which is not allowed
    },
    disconnect => sub { # test die from within a callback
	die "You can't disconnect that easily!\n";
    },
    "*" => sub {
	$called{$_}++;
        return;
    }
};
is keys %{ $dbh->{Callbacks} }, 4;

is ref $dbh->{Callbacks}->{ping}, 'CODE';

$_ = 42;
ok $dbh->ping;
is $called{ping}, 1;
is $_, 42, '$_ not altered by callback';

ok $dbh->ping;
is $called{ping}, 2;

ok $dbh->type_info_all;
is $called{type_info_all}, 1, 'fallback callback';

my $attr;
eval { $dbh->quote_identifier('foo','bar', $attr) };
is $called{quote_identifier}, 1;
ok $@, 'quote_identifier callback caused fatal error';
is ref $attr, 'HASH', 'param modified by callback - not recommended!';

ok !eval { $dbh->disconnect };
ok $@, "You can't disconnect that easily!\n";

$dbh->{Callbacks} = undef;
ok $dbh->ping;
is $called{ping}, 2; # no change


# --- test skipping dispatch and fallback callbacks

$dbh->{Callbacks} = {
    ping => sub {
        undef $_;   # tell dispatch to not call the method
        return "42 bells";
    },
    data_sources => sub {
        my ($h, $values_to_return) = @_;
        undef $_;   # tell dispatch to not call the method
        my @ret = 11..10+($values_to_return||0);
        return @ret;
    },
    commit => sub {     # test using set_err within a callback
        my $h = shift;
        undef $_;   # tell dispatch to not call the method
	return $h->set_err(42, "faked commit failure");
    },
};

# these tests are slightly convoluted because messing with the stack is bad for
# your mental health
my $rv = $dbh->ping;
is $rv, "42 bells";
my @rv = $dbh->ping;
is scalar @rv, 1, 'should return a single value in list context';
is "@rv", "42 bells";
# test returning lists with different number of args to test
# the stack handling in the dispatch code
is join(":", $dbh->data_sources()),  "";
is join(":", $dbh->data_sources(0)), "";
is join(":", $dbh->data_sources(1)), "11";
is join(":", $dbh->data_sources(2)), "11:12";

{
local $dbh->{RaiseError} = 1;
local $dbh->{PrintError} = 0;
is eval { $dbh->commit }, undef, 'intercepted commit should return undef';
like $@, '/DBD::\w+::db commit failed: faked commit failure/';
is $DBI::err, 42;
is $DBI::errstr, "faked commit failure";
}

# --- test connect_cached.*

=for comment XXX

The big problem here is that conceptually the Callbacks attribute
is applied to the $dbh _during_ the $drh->connect() call, so you can't
set a callback on "connect" on the $dbh because connect isn't called
on the dbh, but on the $drh.

So a "connect" callback would have to be defined on the $drh, but that's
cumbersome for the user and then it would apply to all future connects
using that driver.

The best thing to do is probably to special-case "connect", "connect_cached"
and (the already special-case) "connect_cached.reused".

=cut

my $driver_dsn = (DBI->parse_dsn($dsn))[4] or die 'panic';

my @args = (
    $dsn, 'u', 'p', {
        Callbacks => {
            "connect_cached.new"       => sub {
                my ($dbh, $cb_dsn, $user, $auth, $attr) = @_;
                ok tied(%$dbh), 'connect_cached.new $h is tied (outer) handle'
                    if $dbh; # $dbh is typically undef or a dead/disconnected $dbh
                like $cb_dsn, qr/\Q$driver_dsn/, 'dsn';
                is $user, 'u', 'user';
                is $auth, 'p', 'pass';
                $called{new}++;
                return;
            },
            "connect_cached.reused"    => sub {
                my ($dbh, $cb_dsn, $user, $auth, $attr) = @_;
                ok tied(%$dbh), 'connect_cached.reused $h is tied (outer) handle';
                like $cb_dsn, qr/\Q$driver_dsn/, 'dsn';
                is $user, 'u', 'user';
                is $auth, 'p', 'pass';
                $called{cached}++;
                return;
            },
            "connect_cached.connected" => sub {
                my ($dbh, $cb_dsn, $user, $auth, $attr) = @_;
                ok tied(%$dbh), 'connect_cached.connected $h is tied (outer) handle';
                like $cb_dsn, qr/\Q$driver_dsn/, 'dsn';
                is $user, 'u', 'user';
                is $auth, 'p', 'pass';
                $called{connected}++;
                return;
            },
        }
    }
);

%called = ();

ok $dbh = DBI->connect(@args), "Create handle with callbacks";
is keys %called, 0, 'no callback for plain connect';

ok $dbh = DBI->connect_cached(@args), "Create handle with callbacks";
is $called{new}, 1, "connect_cached.new called";
is $called{cached}, undef, "connect_cached.reused not yet called";
is $called{connected}, 1, "connect_cached.connected called";

ok $dbh = DBI->connect_cached(@args), "Create handle with callbacks";
is $called{cached}, 1, "connect_cached.reused called";
is $called{new}, 1, "connect_cached.new not called again";
is $called{connected}, 1, "connect_cached.connected not called called";


# --- test ChildCallbacks.
%called = ();
$args[-1] = {
    Callbacks => my $dbh_callbacks = {
        ping => sub { $called{ping}++; return; },
        ChildCallbacks => my $sth_callbacks = {
            execute => sub { $called{execute}++; return; },
            fetch   => sub { $called{fetch}++; return; },
        }
    }
};

ok $dbh = DBI->connect(@args), "Create handle with ChildCallbacks";
ok $dbh->ping, 'Ping';
is $called{ping}, 1, 'Ping callback should have been called';
ok my $sth = $dbh->prepare('SELECT name from t'), 'Prepare a statement handle (child)';
ok $sth->{Callbacks}, 'child should have Callbacks';
is $sth->{Callbacks}, $sth_callbacks, "child Callbacks should be ChildCallbacks of parent"
    or diag "(dbh Callbacks is $dbh_callbacks)";
ok $sth->execute, 'Execute';
is $called{execute}, 1, 'Execute callback should have been called';
ok $sth->fetch, 'Fetch';
is $called{fetch}, 1, 'Fetch callback should have been called';

# stress test for stack reallocation and mark handling -- RT#86744
my $stress_count = 3000;
my $place_holders = join(',', ('?') x $stress_count);
my @params = ('t') x $stress_count;
my $stress_dbh = DBI->connect( 'DBI:NullP:test');
my $stress_sth = $stress_dbh->prepare("select 1");
$stress_sth->{Callbacks}{execute} = sub { return; };
$stress_sth->execute(@params);


done_testing();

__END__

A generic 'transparent' callback looks like this:
(this assumes only scalar context will be used)

    sub {
        my $h = shift;
        return if our $avoid_deep_recursion->{"$h $_"}++;
        my $this = $h->$_(@_);
        undef $_;    # tell DBI not to call original method
        return $this; # tell DBI to return this instead
    };

XXX should add a test for this
XXX even better would be to run chunks of the test suite with that as a '*' callback. In theory everything should pass (except this test file, naturally)..
