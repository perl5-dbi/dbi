This patch to DBI-1.40 fixes an error

Can't use an undefined value as an ARRAY reference at DBI.pm line 1735

when using execute_array() with zero values for a bind parameter.  It
includes some new test cases, but not all of the new tests failed
before.

diff -ru DBI-1.40/DBI.pm DBI-1.40-new/DBI.pm
--- DBI-1.40/DBI.pm	2004-01-08 14:03:57.000000000 +0000
+++ DBI-1.40-new/DBI.pm	2004-01-26 10:15:46.000000000 +0000
@@ -1719,7 +1719,7 @@
 
     sub execute_for_fetch {
 	my ($sth, $fetch_tuple_sub, $tuple_status) = @_;
-	@$tuple_status = () if $tuple_status; # reset the status array
+	@$tuple_status = (); # reset the status array
 
 	my ($err_count, %errstr_cache);
 	while ( my $tuple = &$fetch_tuple_sub() ) {
diff -ru DBI-1.40/t/15array.t DBI-1.40-new/t/15array.t
--- DBI-1.40/t/15array.t	2003-08-20 01:15:34.000000000 +0100
+++ DBI-1.40-new/t/15array.t	2004-01-26 10:15:15.000000000 +0000
@@ -3,7 +3,7 @@
 use strict;
 use Test;
 
-BEGIN { plan tests => 34 }
+BEGIN { plan tests => 39 }
 
 use Data::Dumper;
 $Data::Dumper::Indent = 0;
@@ -68,6 +68,25 @@
 $dumped = Dumper($tuple_status);
 ok( $dumped, "[1,1,1]");
 
+# --- with no values for bind params, should execute zero times
+
+@$rows = ();
+ok( $sth->execute_array( { ArrayTupleStatus => $tuple_status },
+        [], [], [], [],
+    ),
+    0);
+ok( @$rows, 0 );
+ok( @$tuple_status, 0 );
+
+# --- catch 'undefined value' bug with zero bind values
+
+@$rows = ();
+my $sth_other = $dbh->prepare("insert", {
+	rows => $rows,		# where to 'insert' (push) the rows
+	NUM_OF_PARAMS => 1,
+});
+ok( $sth_other->execute_array( {}, [] ), 0 );
+ok( @$rows, 0);
 
 # --- ArrayTupleFetch code-ref tests ---
 

-- 
Ed Avis <avised@kbcfp.com>
