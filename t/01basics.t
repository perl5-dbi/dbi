#!../../perl -w

use Config qw(%Config);

$^W=1;
$|=1;

print "1..$tests\n";

sub ok ($$;$) {
    my($n, $ok, $msg) = @_;
        $msg = ($msg) ? " ($msg)" : "";
    ++$t;
    die "sequence error, expected $n but actually $t at line ".(caller)[2]."\n"
                if $n and $n != $t;
    my $line = (caller)[2];
    ($ok) ? print "ok $t at line $line\n" : print "not ok $t\n";
    warn " # failed test $t at line ".(caller)[2]."$msg\n" unless $ok;
    return $ok;
}


use DBI qw(:sql_types :utils :sql_cursor_types);

warn "   Using DBI::PurePerl (DBI_PUREPERL=$DBI::PurePerl) on $Config{archname}\n"
    if $DBI::PurePerl;

if (-f "/dev/null") {
    DBI->trace(42,"/dev/null");
    ok(0, $DBI::dbi_debug == 42, "DBI::dbi_debug=$DBI::dbi_debug");
    DBI->trace(0, undef);
    ok(0, $DBI::dbi_debug ==  0, "DBI::dbi_debug=$DBI::dbi_debug");
}
else {
    ok(0, 1);
    ok(0, 1);
}

$switch = DBI->internal;
ok(0, ref $switch eq 'DBI::dr');

@drivers = DBI->available_drivers(); # at least 'ExampleP' should be installed
print "available_drivers: @drivers\n";
ok(0, @drivers);
ok(0, "@drivers" =~ m/ExampleP/i);	# ignore case for VMS & Win32

# Due to a subtle "feature" of sort, this was broken.
my $num_drivers = DBI->available_drivers;
ok(0, $num_drivers);

$switch->debug(0);
ok(0, 1);
$switch->{DebugDispatch} = 0;	# handled by Switch
ok(0, 1);
$switch->{Warn} = 1;			# handled by DBI core
ok(0, 1);

ok(0, $switch->{'Attribution'} =~ m/DBI.*? by Tim Bunce/);
ok(0, $switch->{'Version'} > 0);

eval { $switch->{FooBarUnknown} = 1 };
ok(0,  $@ =~ /Can't set.*FooBarUnknown/);

eval { $_=$switch->{BarFooUnknown} };
ok(0, $@ =~ /Can't get.*BarFooUnknown/);

ok(0, $switch->{private_test1} = 1);
ok(0, $switch->{private_test1} == 1);

ok(0, !defined $switch->{CachedKids});
ok(0, $switch->{CachedKids} = { });
ok(0, ref $switch->{CachedKids} eq 'HASH');
ok(0, ref $switch->{CachedKids} eq 'HASH');

ok(0, $switch->{Kids} == 0);
ok(0, $switch->{ActiveKids} == 0);
ok(0, $switch->{Active});

$switch->trace_msg("Test \$h->trace_msg text.\n", 1);
DBI->trace_msg("Test DBI->trace_msg text.\n", 1);

# spot check a few of the sql data types
ok(0, SQL_VARCHAR == 12);
ok(0, SQL_ALL_TYPES == 0);

# spot check a few of the sql cursor types
ok(0, SQL_CURSOR_FORWARD_ONLY == 0);
ok(0, SQL_CURSOR_DYNAMIC == 2);

my @is_num = looks_like_number(undef, "", "foo", 1, ".", 2, "2");
ok(0, !defined $is_num[0]);	# undef -> undef
ok(0, !defined $is_num[1]);	# "" -> undef (eg "don't know")
ok(0,  defined $is_num[2]);	# "foo" -> defined false
ok(0,         !$is_num[2]);	# "foo" -> defined false
ok(0,          $is_num[3]); # 1 -> true
ok(0,         !$is_num[4]); # "." -> false
ok(0,          $is_num[5]); # 1 -> true
ok(0,          $is_num[6]); # 1 -> true

ok(0, neat(1+1) eq "2");
ok(0, neat("2") eq "'2'");
ok(0, neat(undef) eq "undef");
ok(0, neat_list([1+1, "2", undef, "foobarbaz"], 8, "|") eq "2|'2'|undef|'foo...'");

ok(0, DBI::hash("foo1"  ) == -1077531989,  DBI::hash("foo1"));
ok(0, DBI::hash("foo1",0) == -1077531989,  DBI::hash("foo1",0));
ok(0, DBI::hash("foo2",0) == -1077531990,  DBI::hash("foo2",0));

if ($DBI::PurePerl && !eval { DBI::hash("foo1",1) }) {
  #warn " DBI::hash type 1 test skipped: $@\n"; # probably Math::BigInt too old
  ok(0, 1);
  ok(0, 1);
}
else {
  ok(0, DBI::hash("foo1",1) == -1263462440,  DBI::hash("foo1",1));
  ok(0, DBI::hash("foo2",1) == -1263462437,  DBI::hash("foo2",1));
}

if (-d ".svn") { # restrict this test to developers
print "Test DBI->installed_versions (for @drivers)\n";
print "(If one of those drivers, or the configuration for it, is bad\n";
print "then these tests can kill or freeze the process here. That's not the DBI's fault.)\n";
$SIG{ALRM} = sub {
    die "Test aborted because a driver (one of: @drivers) hung while loading"
       ." (almost certainly NOT a DBI problem)";
};
alarm(20);
my $installed_versions = DBI->installed_versions;
ok(0, ref $installed_versions eq 'HASH');
ok(0, %$installed_versions);
my @installed_drivers = DBI->installed_versions;
ok(0, @installed_drivers >= 1);
ok(0, grep { $_ eq 'Sponge' } @installed_drivers);
}
else {
ok(0,1) for (1..4);
}

BEGIN { $tests = 47 }
exit 0;
