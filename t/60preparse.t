#!perl -w

use DBI qw(:preparse_flags);

$|=1;
sub ok($;$);

if ($DBI::PurePerl) {
    print "1..0 # Skipped: preparse not supported for DBI::PurePerl\n";
    exit 0;
}

print "1..$tests\n";

my $dbh = DBI->connect("dbi:ExampleP:", "", "", {
	PrintError => 0,
});

sub pp {
    my $dbh = shift;
    my $rv = $dbh->preparse(@_);
    return $rv;
}

# --------------------------------------------------------------------- #
#   DBIpp_cm_cs  /* C style */
#   DBIpp_cm_hs  /* #       */
#   DBIpp_cm_dd  /* --      */
#   DBIpp_cm_br  /* {}      */
#   DBIpp_cm_dw  /* '-- ' dash dash whitespace */
#   DBIpp_cm_XX  /* any of the above */
      
#   DBIpp_ph_qm  /* ?       */
#   DBIpp_ph_cn  /* :1      */
#   DBIpp_ph_cs  /* :name   */
#   DBIpp_ph_sp  /* %s (as return only, not accept)    */
#   DBIpp_ph_XX  /* any of the above */
          
#   DBIpp_st_qq  /* '' char escape */
#   DBIpp_st_bs  /* \  char escape */
#   DBIpp_st_XX  /* any of the above */

# ===================================================================== #
#   pp (h    input      return	        accept	        expected)       #
# ===================================================================== #

## Comments:

 ok pp($dbh, "a#b\nc",	DBIpp_cm_cs,	DBIpp_cm_hs),	"a/*b*/\nc"; 
 ok pp($dbh, "a#b\nc",	DBIpp_cm_dw,	DBIpp_cm_hs),   "a-- b\nc"; 
 ok pp($dbh, "a/*b*/c",	DBIpp_cm_hs,	DBIpp_cm_cs),	"a#b\nc";
 ok pp($dbh, "a{b}c",	DBIpp_cm_cs,	DBIpp_cm_br),	"a/*b*/c";
 ok pp($dbh, "a--b\nc",	DBIpp_cm_br,	DBIpp_cm_dd),	"a{b}\nc";

 ok pp($dbh, "a-- b\n/*c*/d", DBIpp_cm_br, DBIpp_cm_cs|DBIpp_cm_dw), "a{ b}\n{c}d";
 ok pp($dbh, "a/*b*/c#d\ne--f\nh-- i\nj{k}", 0, DBIpp_cm_XX), "a c\ne\nh\nj ";

## Placeholders:

 ok pp($dbh, "a = :1", DBIpp_ph_qm, DBIpp_ph_cn), "a = ?";
 ok pp($dbh, "a = :1", DBIpp_ph_sp, DBIpp_ph_cn), "a = %s";
 ok pp($dbh, "a = ?" , DBIpp_ph_cn, DBIpp_ph_qm), "a = :p1";
 ok pp($dbh, "a = ?" , DBIpp_ph_sp, DBIpp_ph_qm), "a = %s";

 ok pp($dbh, "a = :name",  DBIpp_ph_qm,	DBIpp_ph_cs), "a = ?";
 ok pp($dbh, "a = :name",  DBIpp_ph_sp,	DBIpp_ph_cs), "a = %s";

 ok pp($dbh, "a = ? b = ? c = ?", DBIpp_ph_cn,	DBIpp_ph_XX), "a = :p1 b = :p2 c = :p3";

## Placeholders inside comments (should be ignored where comments style is accepted):

 ok pp( $dbh, 
        "a = ? /*b = :1*/ c = ?", 
        DBIpp_cm_dw|DBIpp_ph_cn, 
        DBIpp_cm_cs|DBIpp_ph_qm), 
        "a = :p1 -- b = :1\n c = :p2";

## Placeholders inside single and double quotes (should be ignored):

 ok pp( $dbh, 
        "a = ? 'b = :1' c = ?", 
        DBIpp_ph_cn, 
        DBIpp_ph_XX), 
        "a = :p1 'b = :1' c = :p2";

 ok pp( $dbh, 
        'a = ? "b = :1" c = ?', 
        DBIpp_ph_cn, 
        DBIpp_ph_XX), 
        'a = :p1 "b = :1" c = :p2';

## Comments inside single and double quotes (should be ignored):

 ok pp( $dbh, 
        "a = ? '{b = :1}' c = ?", 
        DBIpp_cm_cs|DBIpp_ph_cn, 
        DBIpp_cm_XX|DBIpp_ph_qm), 
        "a = :p1 '{b = :1}' c = :p2";

 ok pp( $dbh, 
        'a = ? "/*b = :1*/" c = ?', 
        DBIpp_cm_dw|DBIpp_ph_cn, 
        DBIpp_cm_XX|DBIpp_ph_qm), 
        'a = :p1 "/*b = :1*/" c = :p2';

## Single and double quoted strings starting inside comments (should be ignored):

 ok pp( $dbh, 
        'a = ? /*"b = :1 */ c = ?', 
        DBIpp_cm_br|DBIpp_ph_cn, 
        DBIpp_cm_XX|DBIpp_ph_qm), 
        'a = :p1 {"b = :1 } c = :p2';

## Check error conditions are trapped:

 ok pp($dbh, "a = :value and b = :1", DBIpp_ph_qm, DBIpp_ph_cs|DBIpp_ph_cn), undef;
 ok $DBI::err;
 ok $DBI::errstr, "preparse found mixed placeholder styles (:1 / :name)";

 ok pp($dbh, "a = :1 and b = :3", DBIpp_ph_qm,	DBIpp_ph_cn), undef;
 ok $DBI::err;
 ok $DBI::errstr, "preparse found placeholder :3 out of sequence, expected :2";

 ok pp($dbh, "foo ' comment", 0, 0), "foo ' comment";
 ok $DBI::err;
 ok $DBI::errstr, "preparse found unterminated single-quoted string";

 ok pp($dbh, 'foo " comment', 0, 0), 'foo " comment';
 ok $DBI::err;
 ok $DBI::errstr, "preparse found unterminated double-quoted string";

 ok pp($dbh, 'foo /* comment', DBIpp_cm_XX, DBIpp_cm_XX), 'foo /* comment';
 ok $DBI::err;
 ok $DBI::errstr, "preparse found unterminated bracketed C-style comment";

 ok pp($dbh, 'foo { comment', DBIpp_cm_XX, DBIpp_cm_XX), 'foo { comment';
 ok $DBI::err;
 ok $DBI::errstr, "preparse found unterminated bracketed {...} comment";

# --------------------------------------------------------------------- #

$dbh->disconnect;

BEGIN { $tests = 38; }

sub ok ($;$) {
    my ($result, $expected) = @_;
    my $ok;
    if (@_ == 1) {
	$ok = $result;
    } elsif (!defined $expected) {
	$ok = !defined $result;
    } elsif (!defined $result) {
	$ok = 0;
    } else {
	$ok = $result eq $expected;
    }
    ++$t;
    ($ok) ? print "ok $t\n" : print "not ok $t\n";
    $expected = "undef" if !defined $expected;
    $result   = "undef" if !defined $result;
    $expected =~ s/\n/\\n/g;
    $result   =~ s/\n/\\n/g;
    warn "# failed test $t at line ".(caller)[2]."\n\texpected [$expected],\n\t     got [$result]\n" unless $ok;
    return $ok;
}


