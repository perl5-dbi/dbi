#!perl -w
# vim:sw=4:ts=8

use strict;
use Test::More;
use DBI;

BEGIN { plan tests => 32 }

$|=1;

# Connect to the example driver.
ok( my $dbh = DBI->connect('dbi:ExampleP:dummy', '', '',
                           { PrintError => 0,
                             RaiseError => 1,
                             PrintWarn => 1,
                           })
);

# Clean up when we're done.
END { $dbh->disconnect if $dbh };


# ------ Check the database handle attributes.

is( $dbh->{TraceLevel}, $DBI::dbi_debug & 0xF);

my @names = qw(
	SQL
	foo bar baz boo bop
);
my %flag;

foreach my $name (@names) {
    print "trace_flag $name\n";
    ok( my $flag1 = $dbh->trace_flag($name) );
    ok( my $flag2 = $dbh->trace_flags($name) );
    is( $flag1, $flag2 );
    $flag{$name} = $flag1;
}
is keys %flag, @names;

{
print "unknown trace_flag\n";
my $warn = 0;
local $SIG{__WARN__} = sub { ($_[0] =~ /unknown/i) ? ++$warn : warn @_ };
is $dbh->trace_flag("nonesuch"), undef;
is $warn, 0;
is $dbh->trace_flags("nonesuch"), 0;
is $warn, 1;
}

print "trace file & TraceLevel changes\n";
ok( my $sth = $dbh->prepare("select ctime, name from foo") );

my $trace_file = "dbitrace.log";
1 while unlink $trace_file;
$sth->trace(2, $trace_file);
ok( -f $trace_file );
is( $sth->{TraceLevel}, 2 );
$sth->{TraceLevel} = 0;
is( $sth->{TraceLevel}, 0 );
$sth->{TraceLevel} = 3;
is( $sth->{TraceLevel}, 3 );
$sth->trace(0);			# set to 0 before return to STDERR
is( $sth->{TraceLevel}, 0 );
$sth->trace(0, "STDERR");	# close $trace_file
ok( -s $trace_file );

1;
# end
