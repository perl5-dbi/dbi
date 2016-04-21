use warnings;
use strict;
use Scalar::Util qw( weaken reftype refaddr blessed );

use DBI;
use B ();
use Tie::Hash ();
use Test::More;

my (%weak_dbhs, %weak_caches);

# past this scope everything should be gone
{

### get two identical connections
  my @dbhs = map { DBI->connect('dbi:ExampleP::memory:', undef, undef, { RaiseError => 1 }) } (1,2);

### get weakrefs on both handles
  %weak_dbhs = map { refdesc($_) => $_ } @dbhs;
  weaken $_ for values %weak_dbhs;

### tie the first one's cache
  if (1) {
    ok(
      tie( my %cache, 'Tie::StdHash'),
      refdesc($dbhs[0]) . ' cache tied'
    );
    $dbhs[0]->{CachedKids} = \%cache;
  }

### prepare something on both
  $_->prepare_cached( 'SELECT name FROM .' )
    for @dbhs;

### get weakrefs of both caches
  %weak_caches = map {
    sprintf( 'statement cache of %s (%s)',
      refdesc($_),
      refdesc($_->{CachedKids})
    ) => $_->{CachedKids}
  } @dbhs;
  weaken $_ for values %weak_caches;

### check both caches have entries
  is (scalar keys %{$weak_caches{$_}}, 1, "One cached statement found in $_")
    for keys %weak_caches;

### check both caches have sane refcounts
  is ( refcount( $weak_caches{$_} ), 1, "Refcount of $_ correct")
    for keys %weak_caches;

### check both dbh have sane refcounts
  is ( refcount( $weak_dbhs{$_} ), 1, "Refcount of $_ correct")
    for keys %weak_dbhs;

  note "Exiting scope";
  @dbhs=();
}

# check both $dbh weakrefs are gone
is ($weak_dbhs{$_}, undef, "$_ garbage collected")
  for keys %weak_dbhs;

is ($weak_caches{$_}, undef, "$_ garbage collected")
  for keys %weak_caches;



sub refdesc {
  sprintf '%s%s(0x%x)',
    ( defined( $_[1] = blessed $_[0]) ? "$_[1]=" : '' ),
    reftype $_[0],
    refaddr($_[0]),
  ;
}

sub refcount {
  B::svref_2object($_[0])->REFCNT;
}

done_testing;
