#!perl -w

use strict;

use Test::More;
use DBI;

BEGIN {
        plan skip_all => '$h->{Callbacks} attribute not supported for DBI::PurePerl'
                if $DBI::PurePerl && $DBI::PurePerl; # doubled to avoid typo warning
        plan tests => 24;
}

$| = 1;
my $dsn = "dbi:ExampleP:";
my %called;

ok my $dbh = DBI->connect($dsn, '', ''), "Create dbh";

is $dbh->{Callbacks}, undef, "Callbacks initially undef";
ok $dbh->{Callbacks} = my $cb = { };
is ref $dbh->{Callbacks}, 'HASH', "Callbacks can be set to a hash ref";
is $dbh->{Callbacks}, $cb, "Callbacks set to same hash ref";

$dbh->{Callbacks} = undef;
is $dbh->{Callbacks}, undef, "Callbacks set to undef again";

ok $dbh->{Callbacks} = { ping => sub { $called{ping}++; return; } };
is keys %{ $dbh->{Callbacks} }, 1;
is ref $dbh->{Callbacks}->{ping}, 'CODE';
ok $dbh->ping;
is $called{ping}, 1;
ok $dbh->ping;
is $called{ping}, 2;
$dbh->{Callbacks} = undef;
ok $dbh->ping;
is $called{ping}, 2;

=for comment XXX

The big problem here is that conceptually the Callbacks attribute
is # applied to the $dbh _during_ the $drh->connect() call, so you can't
set a callback on "connect" on the $dbh because connect isn't called
on the dbh, but on the $drh.

So a "connect" callback would have to be defined on the $drh, but that's
cumbersom for the user and then it would apply to all future connects
using that driver.

The best thing to do is probably to special-case "connect", "connect_cached"
and (the already special-case) "connect_cached.reused".

=cut

my @args = (
    $dsn, '', '', {
        Callbacks => {
            connect                 => sub { $called{connect}++; return; },
            "connect_cached.reused" => sub { $called{cached}++; return; },
        }
    }
);

ok $dbh = DBI->connect(@args), "Create handle with callbacks";
is $called{connect}, 1, "Connect callback called once.";
is $called{cached}, undef, "Cached not yet called";

ok $dbh = DBI->connect_cached(@args), "Create handle with callbacks";
is $called{connect}, 2, "Connect callback called by connect_cached.";
is $called{cached}, undef, "Cached still not yet called";

ok $dbh = DBI->connect_cached(@args), "Create handle with callbacks";
is $called{connect}, 3, "Connect callback called by second connect_cached.";
is $called{cached}, 1, "Cached called";

