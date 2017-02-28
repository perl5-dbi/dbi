#!perl -w
$| = 1;

use strict;
use warnings;

require DBD::DBM;

use File::Path;
use File::Spec;
use Test::More;
use Cwd;
use Config qw(%Config);
use Storable qw(dclone);

my $using_dbd_gofer = ( $ENV{DBI_AUTOPROXY} || '' ) =~ /^dbi:Gofer.*transport=/i;

use DBI;
use vars qw( @mldbm_types @dbm_types );

BEGIN
{

    # 0=SQL::Statement if avail, 1=DBI::SQL::Nano
    # next line forces use of Nano rather than default behaviour
    # $ENV{DBI_SQL_NANO}=1;
    # This is done in zv*n*_50dbm_simple.t

    if ( eval { require 'MLDBM.pm'; } )
    {
        push @mldbm_types, qw(Data::Dumper Storable);                             # both in CORE
        push @mldbm_types, 'FreezeThaw' if eval { require 'FreezeThaw.pm' };
        push @mldbm_types, 'YAML' if eval { require MLDBM::Serializer::YAML; };
        push @mldbm_types, 'JSON' if eval { require MLDBM::Serializer::JSON; };
    }

    # Potential DBM modules in preference order (SDBM_File first)
    # skip NDBM and ODBM as they don't support EXISTS
    my @dbms     = qw(SDBM_File GDBM_File DB_File BerkeleyDB NDBM_File ODBM_File);
    my @use_dbms = @ARGV;
    if ( !@use_dbms && $ENV{DBD_DBM_TEST_BACKENDS} )
    {
        @use_dbms = split ' ', $ENV{DBD_DBM_TEST_BACKENDS};
    }

    if ( lc "@use_dbms" eq "all" )
    {
        # test with as many of the major DBM types as are available
        @dbm_types = grep {
            eval { local $^W; require "$_.pm" }
        } @dbms;
    }
    elsif (@use_dbms)
    {
        @dbm_types = @use_dbms;
    }
    else
    {
        # we only test SDBM_File by default to avoid tripping up
        # on any broken DBM's that may be installed in odd places.
        # It's only DBD::DBM we're trying to test here.
        # (However, if SDBM_File is not available, then use another.)
        for my $dbm (@dbms)
        {
            if ( eval { local $^W; require "$dbm.pm" } )
            {
                @dbm_types = ($dbm);
                last;
            }
        }
    }

    if ( eval { require List::MoreUtils; } )
    {
        List::MoreUtils->import("part");
    }
    else
    {
        # XXX from PP part of List::MoreUtils
        eval <<'EOP';
sub part(&@) {
    my ($code, @list) = @_;
    my @parts;
    push @{ $parts[$code->($_)] }, $_  for @list;
    return @parts;
}
EOP
    }
}

my $haveSS = DBD::DBM::Statement->isa('SQL::Statement');

plan skip_all => "DBI::SQL::Nano is being used" unless ( $haveSS );
plan skip_all => "Not running with MLDBM" unless ( @mldbm_types );

do "./t/lib.pl";

my $dir = test_dir ();

my $dbh = DBI->connect( 'dbi:DBM:', undef, undef, { f_dir => $dir, } );

my $suffix;
my $tbl_meta;

sub break_at_warn
{
    note "break here";
}
$SIG{__WARN__} = \&break_at_warn;
$SIG{__DIE__} = \&break_at_warn;

sub load_tables
{
    my ( $dbmtype, $dbmmldbm ) = @_;
    my $last_suffix;

    if ($using_dbd_gofer)
    {
	$dbh->disconnect();
	$dbh = DBI->connect( "dbi:DBM:", undef, undef, { f_dir => $dir, dbm_type => $dbmtype, dbm_mldbm => $dbmmldbm } );
    }
    else
    {
	$last_suffix = $suffix;
	$dbh->{dbm_type}  = $dbmtype;
	$dbh->{dbm_mldbm} = $dbmmldbm;
    }

    (my $serializer = $dbmmldbm ) =~ s/::/_/g;
    $suffix = join( "_", $$, $dbmtype, $serializer );

    if ($last_suffix)
    {
        for my $table (qw(APPL_%s PREC_%s NODE_%s LANDSCAPE_%s CONTACT_%s NM_LANDSCAPE_%s APPL_CONTACT_%s))
        {
            my $readsql = sprintf "SELECT * FROM $table", $last_suffix;
            my $impsql = sprintf "CREATE TABLE $table AS IMPORT (?)", $suffix;
            my ($readsth);
            ok( $readsth = $dbh->prepare($readsql), "prepare: $readsql" );
            ok( $readsth->execute(), "execute: $readsql" );
            ok( $dbh->do( $impsql, {}, $readsth ), $impsql ) or warn $dbh->errstr();
        }
    }
    else
    {
        for my $sql ( split( "\n", join( '', <<'EOD' ) ) )
CREATE TABLE APPL_%s (id INT, applname CHAR, appluniq CHAR, version CHAR, appl_type CHAR)
CREATE TABLE PREC_%s (id INT, appl_id INT, node_id INT, precedence INT)
CREATE TABLE NODE_%s (id INT, nodename CHAR, os CHAR, version CHAR)
CREATE TABLE LANDSCAPE_%s (id INT, landscapename CHAR)
CREATE TABLE CONTACT_%s (id INT, surname CHAR, familyname CHAR, phone CHAR, userid CHAR, mailaddr CHAR)
CREATE TABLE NM_LANDSCAPE_%s (id INT, ls_id INT, obj_id INT, obj_type INT)
CREATE TABLE APPL_CONTACT_%s (id INT, contact_id INT, appl_id INT, contact_type CHAR)

INSERT INTO APPL_%s VALUES ( 1, 'ZQF', 'ZFQLIN', '10.2.0.4', 'Oracle DB')
INSERT INTO APPL_%s VALUES ( 2, 'YRA', 'YRA-UX', '10.2.0.2', 'Oracle DB')
INSERT INTO APPL_%s VALUES ( 3, 'PRN1', 'PRN1-4.B2', '1.1.22', 'CUPS' )
INSERT INTO APPL_%s VALUES ( 4, 'PRN2', 'PRN2-4.B2', '1.1.22', 'CUPS' )
INSERT INTO APPL_%s VALUES ( 5, 'PRN1', 'PRN1-4.B1', '1.1.22', 'CUPS' )
INSERT INTO APPL_%s VALUES ( 7, 'PRN2', 'PRN2-4.B1', '1.1.22', 'CUPS' )
INSERT INTO APPL_%s VALUES ( 8, 'sql-stmt', 'SQL::Statement', '1.21', 'Project Web-Site')
INSERT INTO APPL_%s VALUES ( 9, 'cpan.org', 'http://www.cpan.org/', '1.0', 'Web-Site')
INSERT INTO APPL_%s VALUES (10, 'httpd', 'cpan-apache', '2.2.13', 'Web-Server')
INSERT INTO APPL_%s VALUES (11, 'cpan-mods', 'cpan-mods', '8.4.1', 'PostgreSQL DB')
INSERT INTO APPL_%s VALUES (12, 'cpan-authors', 'cpan-authors', '8.4.1', 'PostgreSQL DB')

INSERT INTO NODE_%s VALUES ( 1, 'ernie', 'RHEL', '5.2')
INSERT INTO NODE_%s VALUES ( 2, 'bert', 'RHEL', '5.2')
INSERT INTO NODE_%s VALUES ( 3, 'statler', 'FreeBSD', '7.2')
INSERT INTO NODE_%s VALUES ( 4, 'waldorf', 'FreeBSD', '7.2')
INSERT INTO NODE_%s VALUES ( 5, 'piggy', 'NetBSD', '5.0.2')
INSERT INTO NODE_%s VALUES ( 6, 'kermit', 'NetBSD', '5.0.2')
INSERT INTO NODE_%s VALUES ( 7, 'samson', 'NetBSD', '5.0.2')
INSERT INTO NODE_%s VALUES ( 8, 'tiffy', 'NetBSD', '5.0.2')
INSERT INTO NODE_%s VALUES ( 9, 'rowlf', 'Debian Lenny', '5.0')
INSERT INTO NODE_%s VALUES (10, 'fozzy', 'Debian Lenny', '5.0')

INSERT INTO PREC_%s VALUES ( 1,  1,  1, 1)
INSERT INTO PREC_%s VALUES ( 2,  1,  2, 2)
INSERT INTO PREC_%s VALUES ( 3,  2,  2, 1)
INSERT INTO PREC_%s VALUES ( 4,  2,  1, 2)
INSERT INTO PREC_%s VALUES ( 5,  3,  5, 1)
INSERT INTO PREC_%s VALUES ( 6,  3,  7, 2)
INSERT INTO PREC_%s VALUES ( 7,  4,  6, 1)
INSERT INTO PREC_%s VALUES ( 8,  4,  8, 2)
INSERT INTO PREC_%s VALUES ( 9,  5,  7, 1)
INSERT INTO PREC_%s VALUES (10,  5,  5, 2)
INSERT INTO PREC_%s VALUES (11,  6,  8, 1)
INSERT INTO PREC_%s VALUES (12,  7,  6, 2)
INSERT INTO PREC_%s VALUES (13, 10,  9, 1)
INSERT INTO PREC_%s VALUES (14, 10, 10, 1)
INSERT INTO PREC_%s VALUES (15,  8,  9, 1)
INSERT INTO PREC_%s VALUES (16,  8, 10, 1)
INSERT INTO PREC_%s VALUES (17,  9,  9, 1)
INSERT INTO PREC_%s VALUES (18,  9, 10, 1)
INSERT INTO PREC_%s VALUES (19, 11,  3, 1)
INSERT INTO PREC_%s VALUES (20, 11,  4, 2)
INSERT INTO PREC_%s VALUES (21, 12,  4, 1)
INSERT INTO PREC_%s VALUES (22, 12,  3, 2)

INSERT INTO LANDSCAPE_%s VALUES (1, 'Logistic')
INSERT INTO LANDSCAPE_%s VALUES (2, 'Infrastructure')
INSERT INTO LANDSCAPE_%s VALUES (3, 'CPAN')

INSERT INTO CONTACT_%s VALUES ( 1, 'Hans Peter', 'Mueller', '12345', 'HPMUE', 'hp-mueller@here.com')
INSERT INTO CONTACT_%s VALUES ( 2, 'Knut', 'Inge', '54321', 'KINGE', 'k-inge@here.com')
INSERT INTO CONTACT_%s VALUES ( 3, 'Lola', 'Nguyen', '+1-123-45678-90', 'LNYUG', 'lola.ngyuen@customer.com')
INSERT INTO CONTACT_%s VALUES ( 4, 'Helge', 'Brunft', '+41-123-45678-09', 'HBRUN', 'helge.brunft@external-dc.at')

-- TYPE: 1: APPL 2: NODE 3: CONTACT
INSERT INTO NM_LANDSCAPE_%s VALUES ( 1, 1, 1, 2)
INSERT INTO NM_LANDSCAPE_%s VALUES ( 2, 1, 2, 2)
INSERT INTO NM_LANDSCAPE_%s VALUES ( 3, 3, 3, 2)
INSERT INTO NM_LANDSCAPE_%s VALUES ( 4, 3, 4, 2)
INSERT INTO NM_LANDSCAPE_%s VALUES ( 5, 2, 5, 2)
INSERT INTO NM_LANDSCAPE_%s VALUES ( 6, 2, 6, 2)
INSERT INTO NM_LANDSCAPE_%s VALUES ( 7, 2, 7, 2)
INSERT INTO NM_LANDSCAPE_%s VALUES ( 8, 2, 8, 2)
INSERT INTO NM_LANDSCAPE_%s VALUES ( 9, 3, 9, 2)
INSERT INTO NM_LANDSCAPE_%s VALUES (10, 3,10, 2)
INSERT INTO NM_LANDSCAPE_%s VALUES (11, 1, 1, 1)
INSERT INTO NM_LANDSCAPE_%s VALUES (12, 2, 2, 1)
INSERT INTO NM_LANDSCAPE_%s VALUES (13, 2, 2, 3)
INSERT INTO NM_LANDSCAPE_%s VALUES (14, 3, 1, 3)

INSERT INTO APPL_CONTACT_%s VALUES (1, 3, 1, 'OWNER')
INSERT INTO APPL_CONTACT_%s VALUES (2, 3, 2, 'OWNER')
INSERT INTO APPL_CONTACT_%s VALUES (3, 4, 3, 'ADMIN')
INSERT INTO APPL_CONTACT_%s VALUES (4, 4, 4, 'ADMIN')
INSERT INTO APPL_CONTACT_%s VALUES (5, 4, 5, 'ADMIN')
INSERT INTO APPL_CONTACT_%s VALUES (6, 4, 6, 'ADMIN')
EOD
        {
            chomp $sql;
            $sql =~ s/^\s+//;
            $sql =~ s/--.*$//;
            $sql =~ s/\s+$//;
            next if ( '' eq $sql );
            $sql = sprintf $sql, $suffix;
            ok( $dbh->do($sql), $sql );
        }
    }

    for my $table (qw(APPL_%s PREC_%s NODE_%s LANDSCAPE_%s CONTACT_%s NM_LANDSCAPE_%s APPL_CONTACT_%s))
    {
	my $tbl_name = lc sprintf($table, $suffix);
	$tbl_meta->{$tbl_name} = { dbm_type => $dbmtype, dbm_mldbm => $dbmmldbm };
    }

    unless ($using_dbd_gofer)
    {
	my $tbl_known_meta = $dbh->dbm_get_meta( "+", [ qw(dbm_type dbm_mldbm) ] );
	is_deeply( $tbl_known_meta, $tbl_meta, "Know meta" );
    }
}

sub do_tests
{
    my ( $dbmtype, $serializer ) = @_;

    note "Running do_tests for $dbmtype + $serializer";

    load_tables( $dbmtype, $serializer );

    my %joins;
    my $sql;

    $sql = join( " ",
                 q{SELECT applname, appluniq, version, nodename },
                 sprintf( q{FROM APPL_%s, PREC_%s, NODE_%s },                                ($suffix) x 3 ),
                 sprintf( q{WHERE appl_type LIKE '%%DB' AND APPL_%s.id=PREC_%s.appl_id AND}, ($suffix) x 2 ),
                 sprintf( q{PREC_%s.node_id=NODE_%s.id},                                     ($suffix) x 2 ),
               );

    $joins{$sql} = [
                     'ZQF~ZFQLIN~10.2.0.4~ernie',               'ZQF~ZFQLIN~10.2.0.4~bert',
                     'YRA~YRA-UX~10.2.0.2~bert',                'YRA~YRA-UX~10.2.0.2~ernie',
                     'cpan-mods~cpan-mods~8.4.1~statler',       'cpan-mods~cpan-mods~8.4.1~waldorf',
                     'cpan-authors~cpan-authors~8.4.1~waldorf', 'cpan-authors~cpan-authors~8.4.1~statler',
                   ];

    $sql = join( " ",
                 q{SELECT applname, appluniq, version, landscapename, nodename},
                 sprintf( q{FROM APPL_%s, PREC_%s, NODE_%s, LANDSCAPE_%s, NM_LANDSCAPE_%s},        ($suffix) x 5 ),
                 sprintf( q{WHERE appl_type LIKE '%%DB' AND APPL_%s.id=PREC_%s.appl_id AND},       ($suffix) x 2 ),
                 sprintf( q{PREC_%s.node_id=NODE_%s.id AND NM_LANDSCAPE_%s.obj_id=APPL_%s.id AND}, ($suffix) x 4 ),
                 sprintf( q{NM_LANDSCAPE_%s.obj_type=1 AND NM_LANDSCAPE_%s.ls_id=LANDSCAPE_%s.id}, ($suffix) x 3 ),
               );
    $joins{$sql} = [
                     'ZQF~ZFQLIN~10.2.0.4~Logistic~ernie',      'ZQF~ZFQLIN~10.2.0.4~Logistic~bert',
                     'YRA~YRA-UX~10.2.0.2~Infrastructure~bert', 'YRA~YRA-UX~10.2.0.2~Infrastructure~ernie',
                   ];
    $sql = join( " ",
                 q{SELECT applname, appluniq, version, surname, familyname, phone, nodename},
                 sprintf( q{FROM APPL_%s, PREC_%s, NODE_%s, CONTACT_%s, APPL_CONTACT_%s},           ($suffix) x 5 ),
                 sprintf( q{WHERE appl_type='CUPS' AND APPL_%s.id=PREC_%s.appl_id AND},             ($suffix) x 2 ),
                 sprintf( q{PREC_%s.node_id=NODE_%s.id AND APPL_CONTACT_%s.appl_id=APPL_%s.id AND}, ($suffix) x 4 ),
                 sprintf( q{APPL_CONTACT_%s.contact_id=CONTACT_%s.id AND PREC_%s.PRECEDENCE=1},     ($suffix) x 3 ),
               );
    $joins{$sql} = [
                     'PRN1~PRN1-4.B2~1.1.22~Helge~Brunft~+41-123-45678-09~piggy',
                     'PRN2~PRN2-4.B2~1.1.22~Helge~Brunft~+41-123-45678-09~kermit',
                     'PRN1~PRN1-4.B1~1.1.22~Helge~Brunft~+41-123-45678-09~samson',
                   ];
    $sql = join( " ",
                 q{SELECT DISTINCT applname, appluniq, version, surname, familyname, phone, nodename},
                 sprintf( q{FROM APPL_%s, PREC_%s, NODE_%s, CONTACT_%s, APPL_CONTACT_%s},       ($suffix) x 5 ),
                 sprintf( q{WHERE appl_type='CUPS' AND APPL_%s.id=PREC_%s.appl_id AND},         ($suffix) x 2 ),
                 sprintf( q{PREC_%s.node_id=NODE_%s.id AND APPL_CONTACT_%s.appl_id=APPL_%s.id}, ($suffix) x 4 ),
                 sprintf( q{AND APPL_CONTACT_%s.contact_id=CONTACT_%s.id},                      ($suffix) x 2 ),
               );
    $joins{$sql} = [
                     'PRN1~PRN1-4.B1~1.1.22~Helge~Brunft~+41-123-45678-09~piggy',
                     'PRN1~PRN1-4.B2~1.1.22~Helge~Brunft~+41-123-45678-09~piggy',
                     'PRN1~PRN1-4.B1~1.1.22~Helge~Brunft~+41-123-45678-09~samson',
                     'PRN1~PRN1-4.B2~1.1.22~Helge~Brunft~+41-123-45678-09~samson',
                     'PRN2~PRN2-4.B2~1.1.22~Helge~Brunft~+41-123-45678-09~kermit',
                     'PRN2~PRN2-4.B2~1.1.22~Helge~Brunft~+41-123-45678-09~tiffy',
                   ];
    $sql = join( " ",
                 q{SELECT CONCAT('[% NOW %]') AS "timestamp", applname, appluniq, version, nodename},
                 sprintf( q{FROM APPL_%s, PREC_%s, NODE_%s},                                 ($suffix) x 3 ),
                 sprintf( q{WHERE appl_type LIKE '%%DB' AND APPL_%s.id=PREC_%s.appl_id AND}, ($suffix) x 2 ),
                 sprintf( q{PREC_%s.node_id=NODE_%s.id},                                     ($suffix) x 2 ),
               );
    $joins{$sql} = [
                     '[% NOW %]~ZQF~ZFQLIN~10.2.0.4~ernie',
                     '[% NOW %]~ZQF~ZFQLIN~10.2.0.4~bert',
                     '[% NOW %]~YRA~YRA-UX~10.2.0.2~bert',
                     '[% NOW %]~YRA~YRA-UX~10.2.0.2~ernie',
                     '[% NOW %]~cpan-mods~cpan-mods~8.4.1~statler',
                     '[% NOW %]~cpan-mods~cpan-mods~8.4.1~waldorf',
                     '[% NOW %]~cpan-authors~cpan-authors~8.4.1~waldorf',
                     '[% NOW %]~cpan-authors~cpan-authors~8.4.1~statler',
                   ];

    while ( my ( $sql, $result ) = each(%joins) )
    {
        my $sth = $dbh->prepare($sql);
        eval { $sth->execute() };
        warn $@ if $@;
        my @res;
        while ( my $row = $sth->fetchrow_arrayref() )
        {
            push( @res, join( '~', @{$row} ) );
        }
        is( join( '^', sort @res ), join( '^', sort @{$result} ), $sql );
    }
}

foreach my $dbmtype (@dbm_types)
{
    foreach my $serializer (@mldbm_types)
    {
        do_tests( $dbmtype, $serializer );
    }
}

done_testing();
