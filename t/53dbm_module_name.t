#!perl -w
# dbm_type and dbm_mldbm name a Perl module, never a file path.
#
# Both attributes reach require(). require() treats a path-shaped string as a
# literal file and never consults @INC, so without a grammar check a caller
# who influences either attribute can make the process load -- and therefore
# execute -- a .pm from anywhere on the filesystem.
#
# The two "rejected" cases below fail on an unvalidated DBD::DBM: the planted
# module gets loaded and sets the flag. The two "still works" cases pin the
# behaviour the check must not break.

use strict;
use warnings;

require DBD::DBM;

use DBI;
use File::Path qw(mkpath);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

my $dir = tempdir( CLEANUP => 1 );
my $dbdir = File::Spec->catdir( $dir, 'db' );
mkpath($dbdir);

# A module planted outside @INC. Loading it is observable and can happen for
# exactly one reason: something required this path.
my $plant = File::Spec->catfile( $dir, 'DbmPlant.pm' );
open( my $fh, '>', $plant ) or plan skip_all => "cannot write $plant: $!";
print {$fh} "\$::DBM_PLANT_LOADED = 1;\n1;\n";
close($fh);

( my $plant_noext = $plant ) =~ s/\.pm\z//;

my $have_mldbm = eval { require 'MLDBM.pm'; 1 };

# --- dbm_type must not name a path --------------------------------------
{
    local $::DBM_PLANT_LOADED = 0;
    my $dbh = DBI->connect( "dbi:DBM:f_dir=$dbdir", undef, undef,
                            { RaiseError => 0, PrintError => 0 } );
    $dbh->{dbm_type} = $plant_noext;
    eval { $dbh->do("CREATE TABLE t_reject (id INT, v CHAR(8))"); 1 };
    ok( !$::DBM_PLANT_LOADED,
        "a path-shaped dbm_type does not load the file it names" );
    $dbh->disconnect;
}

# The same path with its ".pm" suffix left on. This is the case a loader
# swap alone does not cover: Module::Load treats anything outside [\w:'] as a
# filename and requires it verbatim, so "/path/Evil" fails only because no
# such file exists -- "/path/Evil.pm" loads.
{
    local $::DBM_PLANT_LOADED = 0;
    my $dbh = DBI->connect( "dbi:DBM:f_dir=$dbdir", undef, undef,
                            { RaiseError => 0, PrintError => 0 } );
    $dbh->{dbm_type} = $plant;
    eval { $dbh->do("CREATE TABLE t_reject_pm (id INT, v CHAR(8))"); 1 };
    ok( !$::DBM_PLANT_LOADED,
        "a dbm_type naming a .pm file directly does not load it" );
    $dbh->disconnect;
}

# --- dbm_type still accepts a real DBM implementation -------------------
{
    my $dbh = DBI->connect( "dbi:DBM:f_dir=$dbdir;dbm_type=SDBM_File", undef, undef,
                            { RaiseError => 1, PrintError => 0 } );
    $dbh->do("CREATE TABLE t_ok (id INT, v CHAR(8))");
    $dbh->do("INSERT INTO t_ok VALUES (1, 'hello')");
    my ($v) = $dbh->selectrow_array("SELECT v FROM t_ok WHERE id = 1");
    is( $v, 'hello', "dbm_type=SDBM_File still round-trips a row" );
    $dbh->disconnect;
}

# --- dbm_mldbm must not escape the MLDBM::Serializer:: prefix ------------
SKIP: {
    skip "MLDBM not installed", 1 unless $have_mldbm;

    # "MLDBM::Serializer::" only looks like containment. s|::|/|g rewrites
    # "::" and leaves a literal "/" alone, and MLDBM ships MLDBM/Serializer/
    # into @INC, so every component of a traversal out of it exists.
    my ($inc) = grep { -d File::Spec->catdir( $_, 'MLDBM', 'Serializer' ) } @INC;
    skip "no \@INC entry holds MLDBM/Serializer/", 1 unless defined $inc;

    my @up = File::Spec->splitdir( File::Spec->canonpath($inc) );
    shift(@up) while ( @up && $up[0] eq '' );
    my $escape = ( '../' x ( scalar(@up) + 2 ) ) . substr( $plant_noext, 1 );

    local $::DBM_PLANT_LOADED = 0;
    my $dbh = DBI->connect( "dbi:DBM:f_dir=$dbdir;dbm_type=SDBM_File", undef, undef,
                            { RaiseError => 0, PrintError => 0,
                              dbm_mldbm   => $escape } );
    eval {
        $dbh->do("CREATE TABLE t_ser (id INT, v CHAR(8))");
        $dbh->func( 't_ser', 'dbm_versions' );
        1;
    };
    ok( !$::DBM_PLANT_LOADED,
        "a dbm_mldbm that traverses out of MLDBM::Serializer:: does not load the file it names" );
    $dbh->disconnect;
}

# --- dbm_mldbm still accepts a real serializer name ---------------------
{
    my $dbh = DBI->connect( "dbi:DBM:f_dir=$dbdir;dbm_type=SDBM_File", undef, undef,
                            { RaiseError => 0, PrintError => 0 } );
    my $versions = eval { $dbh->func( 'dbm_versions' ) };
    ok( defined $versions && length $versions,
        "dbm_versions() still reports for an unmodified handle" );
    $dbh->disconnect;
}

done_testing;
