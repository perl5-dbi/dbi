#!perl

use strict;
use warnings;

use Test::More;
eval "use Pod::Spell::CommonMistakes qw( check_pod )";
plan skip_all => "Pod::Spell::CommonMistakes required for testing POD spelling" if $@;

use File::Find;

my @files;
find (sub {
    $File::Find::dir =~ m/\bblib/ and return;
    m/\.pm$/ and push @files, $File::Find::name;
    }, ".");
s{^\./}{} for @files;

foreach my $pm (sort @files) {
    my $result = check_pod ($pm);
    my @keys = keys %$result;

    is (scalar @keys, 0, "$pm");
    @keys or next;

    diag (join "\n", map { "$_\t=> $result->{$_}" } @keys);
    }

done_testing;

1;
