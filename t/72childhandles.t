#!perl -w

use strict;

#
# test script for the ChildHandles attribute
#

use DBI;

use Test;
BEGIN { plan tests => 22; }
{
    # make 10 connections
    my @dbh;
    for (1 .. 10) {
        my $dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1 });
        push(@dbh, $dbh);
    }
    
    # get the driver handle
    my %drivers = DBI->installed_drivers();
    my $driver = $drivers{ExampleP};
    ok($driver);

    # get the kids, should be the 10 connections
    my $db_handles = $driver->{ChildHandles};
    ok(scalar @$db_handles, 10);

    # make sure all the handles are there
    foreach my $h (@dbh) {
        ok(grep { $h == $_ } @$db_handles);
    }
}

# now all the out-of-scope DB handles should be gone
{
    my %drivers = DBI->installed_drivers();
    my $driver = $drivers{ExampleP};

    my $handles = $driver->{ChildHandles};
    my @db_handles = grep { defined } @$handles;
    ok(scalar @db_handles, 0);
}

my $dbh = DBI->connect("dbi:ExampleP:", '', '', { RaiseError=>1 });


# ChildHandles should start with an empty array-ref
my $empty = $dbh->{ChildHandles};
ok(scalar @$empty, 0);

# test child handles for statement handles
{
    my @sth;
    for (1 .. 200) {
        my $sth = $dbh->prepare('SELECT name FROM t');
        push(@sth, $sth);
    }
    my $handles = $dbh->{ChildHandles};
    ok(scalar @$handles, 200);

    # test a recursive walk like the one in the docs
    my @lines;
    sub show_child_handles {
        my ($h, $level) = @_;
        $level ||= 0;
        push(@lines, 
             sprintf "%sh %s %s\n", $h->{Type}, "\t" x $level, $h);
        show_child_handles($_, $level + 1) 
          for (grep { defined } @{$h->{ChildHandles}});
    }   
    show_child_handles($_) for (values %{{DBI->installed_drivers()}});

    ok(scalar @lines, 202);
    ok($lines[0] =~ /^drh/);
    ok($lines[1] =~ /^dbh/);
    ok($lines[2] =~ /^sth/);
}

# they should be gone now
my $handles = $dbh->{ChildHandles};
my @live = grep { defined $_ } @$handles;
ok(scalar @live, 0);

# test that the childhandle array does not grow uncontrollably
{
    for (1 .. 1000) {
        my $sth = $dbh->prepare('SELECT name FROM t');
    }
    my $handles = $dbh->{ChildHandles};
    ok(scalar @$handles < 1000);
    my @live = grep { defined } @$handles;
    ok(scalar @live, 0);
}
