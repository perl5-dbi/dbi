#!perl -w                                         # -*- perl -*-
# vim:sw=4:ts=8
$|=1;

use strict;
use warnings;

use DBI;
use Data::Dumper;
use Test::More;
use DBI::Util::Cache;

plan 'no_plan';

my @cache_classes = qw(DBI::Util::Cache);
push @cache_classes, "Cache::Memory" if eval { require Cache::Memory };

for my $cache_class (@cache_classes) {
    my $cache_obj = $cache_class->new();
    run_tests($cache_obj);
}

sub run_tests {
    my $cache_obj = shift;

    my $tmp;
    my $dsn = "dbi:Gofer:transport=null;policy=classic;dsn=dbi:ExampleP:";
    print " using $cache_obj for $dsn\n";

    is $cache_obj->count, 0, 'cache should be empty to start';

    my $dbh = DBI->connect($dsn, undef, undef, {
        go_cache => $cache_obj,
        RaiseError => 1, PrintError => 0, ShowErrorStatement => 1,
    } );
    ok my $go_transport = $dbh->{go_transport};

    # setup
    $cache_obj->clear;
    is $cache_obj->count, 0, 'cache should be empty after clear';

    $go_transport->transmit_count(0);
    is $go_transport->transmit_count, 0, 'transmit_count should be 0';

    $go_transport->cache_hit(0);
    $go_transport->cache_miss(0);
    $go_transport->cache_store(0);

    # request 1
    ok my $rows1 = $dbh->selectall_arrayref("select name from ?", {}, ".");
    cmp_ok $cache_obj->count, '>', 0, 'cache should not be empty after select';

    is $go_transport->cache_hit, 0;
    is $go_transport->cache_miss, 1;
    is $go_transport->cache_store, 1;

    is $go_transport->transmit_count, 1, 'should make 1 round trip';
    $go_transport->transmit_count(0);
    is $go_transport->transmit_count, 0, 'transmit_count should be 0';

    # request 2
    ok my $rows2 = $dbh->selectall_arrayref("select name from ?", {}, ".");
    is_deeply $rows2, $rows1;
    is $go_transport->transmit_count, 0, 'should make 1 round trip';

    is $go_transport->cache_hit, 1;
    is $go_transport->cache_miss, 1;
    is $go_transport->cache_store, 1;

}
