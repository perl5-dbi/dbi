#!perl -w

use strict;
use Test;
use Data::Dumper;

# handle tests

BEGIN { plan tests => 18 }

use DBI;

my $driver = "ExampleP";

my $drh = DBI->install_driver($driver);
ok($drh);
ok($drh->{Kids}, 0);

# --- handle reference leak tests

sub work {
    my (%args) = @_;
    my $dbh = DBI->connect("dbi:$driver:", '', '');
    ok(ref $dbh->{Driver}) if $args{Driver};
    my $sth = $dbh->prepare_cached("select name from ?");
    ok(ref $sth->{Database}) if $args{Database};
    $dbh->disconnect;
    # both handles should be freed here
}

foreach my $args (
	{},
	{ Driver   => 1 },
	{ Database => 1 },
	{ Driver   => 1, Database => 1 },
) {
    print "ref leak using @{[ %$args ]}\n";
    work( %$args );
    ok($drh->{Kids}, 0);
}

# --- handle take_imp_data test

print "take_imp_data\n";
unless ($DBI::PurePerl) {

my $dbh = DBI->connect("dbi:$driver:", '', '');

#DBI->trace(9);
my $imp_data = $dbh->take_imp_data;
ok($imp_data);
ok(length($imp_data) >= 112); # 112 for 32bit, 116 for 64 bit as of DBI 1.37, but may change
print Dumper($imp_data);

{
my ($tmp, $warn);
local $SIG{__WARN__} = sub { ++$warn if $_[0] =~ /after take_imp_data/ };
ok($tmp=$dbh->{Driver}, undef);
ok($tmp=$dbh->{TraceLevel}, undef);
ok($dbh->disconnect, undef);
ok($dbh->quote(42), undef);
ok($warn, 4);
}

print "use dbi_imp_data\n";
my $dbh2 = DBI->connect("dbi:$driver:", '', '', { dbi_imp_data => $imp_data });
ok($dbh2);
# need a way to test dbi_imp_data has been used

}
else {
    ok(1) for (1..8);
}

exit 0;
