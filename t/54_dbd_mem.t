#!perl -w
$|=1;

use strict;

use Cwd;
use File::Path;
use File::Spec;
use Test::More;

my $using_dbd_gofer = ($ENV{DBI_AUTOPROXY}||"") =~ /^dbi:Gofer.*transport=/i;
$using_dbd_gofer and plan skip_all => "modifying meta data doesn't work with Gofer-AutoProxy";

my $tbl;
BEGIN { $tbl = "db_". $$ . "_" };
#END   { $tbl and unlink glob "${tbl}*" }

use_ok ("DBI");
use_ok ("DBD::Mem");

my $dbh = DBI->connect( "DBI:Mem:", undef, undef, { PrintError => 0, RaiseError => 0, } ); # Can't use DBI::DBD::SqlEngine direct

for my $sql ( split "\n", <<"" )
    CREATE TABLE foo (id INT, foo TEXT)
    CREATE TABLE bar (id INT, baz TEXT)
    INSERT INTO foo VALUES (1, 'Hello world')
    INSERT INTO bar VALUES (1, 'Bugfixes welcome')
    INSERT bar VALUES (2, 'Bug reports, too')
    SELECT foo FROM foo where ID=1
    UPDATE bar SET id=5 WHERE baz='Bugfixes welcome'
    DELETE FROM foo
    DELETE FROM bar WHERE baz='Bugfixes welcome'

{
    my $done;
    $sql =~ s/^\s+//;
    eval { $done = $dbh->do( $sql ); };
    ok( $done, "executed '$sql'" ) or diag $dbh->errstr;
}

done_testing ();
