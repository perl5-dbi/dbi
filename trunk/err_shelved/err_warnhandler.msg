From dbi-users-return-12047-Tim.Bunce=pobox.com@perl.org  Fri Jun 14 07:33:16 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g5E6XEo84932
	for <timbo@localhost>; Fri, 14 Jun 2002 07:33:14 +0100 (BST)
	(envelope-from dbi-users-return-12047-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.21]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 14 Jun 2002 07:33:14 +0100 (BST)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1024018923:20:17194:15; Fri, 14 Jun 2002 01:42:03 GMT
Received: from dolly1.pobox.com ([207.106.49.22]) by punt-2.mail.demon.net
           id aa2018976; 14 Jun 2002 1:41 GMT
Received: from dolly1.pobox.com (localhost.localdomain [127.0.0.1])
	by dolly1.pobox.com (Postfix) with ESMTP id E20132C024
	for <Tim.Bunce@data-plan.com>; Thu, 13 Jun 2002 21:41:52 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [64.70.54.95])
	by dolly1.pobox.com (Postfix) with SMTP id 106D02BFF5
	for <Tim.Bunce@pobox.com>; Thu, 13 Jun 2002 21:41:52 -0400 (EDT)
Received: (qmail 30855 invoked by uid 1005); 14 Jun 2002 01:43:12 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 30833 invoked by uid 76); 14 Jun 2002 01:43:12 -0000
Received: from adsl-64-174-207-130.dsl.lsan03.pacbell.net (HELO dave.net) (64.174.207.130)
  by onion.perl.org (qpsmtpd/0.07b) with SMTP; Fri Jun 14 01:43:12 2002 -0000
Received: (from dave@localhost)
	by dave.net (8.11.6/8.11.6) id g5E1fg304127;
	Thu, 13 Jun 2002 18:41:42 -0700
Date: Thu, 13 Jun 2002 18:41:42 -0700
From: "David L. Good" <dave@dave.net>
To: dbi-users@perl.org
Cc: jurlwin@bellatlantic.net
Subject: DBD::ODBC and Sybase/SQL Server server messages
Message-ID: <20020613184142.A4105@fred.dave.net>
Mail-Followup-To: "David L. Good" <dave@dave.net>,
	dbi-users@perl.org, jurlwin@bellatlantic.net
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
User-Agent: Mutt/1.2.5.1i
Status: RO
Content-Length: 15573
Lines: 473

I just took a look at DBD::ODBC again after nearly a two year hiatus and
discovered that this patch I submitted two years ago was never put in.
The project I was working on at the time got back burnered soon after I
sent in the patch, so I never really checked.  Now I'm starting a similar
project and I think this old patch might still be useful, but I'm not sure
how much stuff has changed since DBD::ODBC 0.28.  I'm including my (rather
longwinded) explanation of what it does and why it might be useful.
Does this seem like something that might be useful to anyone else?
If so, and if nobody else wants to do it, I'll take a look at integrating
it into 0.41.  One potential problem though is that I don't currently have
a box to test it on.

----- Forwarded message from David Good <dgood@stratasource.com> -----

Date: Thu, 29 Jun 2000 13:41:31 -0700
From: David Good <dgood@stratasource.com>
To: dbi-users@isc.org
Cc: jurlwin@bellatlantic.net
Subject: Re: DBD::ODBC and Sybase/SQL Server server messages


On Fri, Apr 28, 2000 at 10:16:58AM -0700, David Good <dgood@stratasource.com> wrote:
> On Fri, Apr 21, 2000 at 05:32:53PM -0700, David Good <dgood@stratasource.com> wrote:
> > I'm using DBD::ODBC to connect to Sybase and MS-SQL Server databases
> > (among others) and I was wondering if there is an easy way to get
> > server messages for things like DBCCs.  In dblib and ct-lib you'd set
> > up a message handler for this.  Indeed, in DBD::Sybase you can set
> > $dbh->{syb_err_handler} to a coderef to handle it.  Looking through the
> > ODBC API, I don't see anything really, really obvious, but I haven't
> > gotten really in-depth yet.  Anyone have any ideas?
> 
> To answer my own question, it turns out that the server messages are
> all there and readily available, they just aren't retrieved unless the
> SQLExecute returns an error status.  I think the most useful method
> for retrieving these is through some sort of callback method similar
> to DBD::Sybase's $dbh->{syb_err_handler}.  Unfortunately, there's no
> way to retrieve the messages while execution is in progress unless
> SQLExecute is run in asynchronous mode.  Now, async mode can be set
> on a per-statement or per-connection basis depending on the data source
> (i.e. some type of data sources can do per-statement async and some can do
> per-connection async).  I suppose the best way to go is to define another
> attribute odbc_async_execute or somesuch and if set, set the async mode by
> whichever means is available.  If anyone has any ideas or suggestions let
> me know as it will probably be a few days before I get started on this...


I've finally finished this.  Here's the details (with the patch following):

I've implemented two separate functions.  The first is an "error
handler" similar to that in DBD::Sybase.  The error handler can be used
to intercept error and status messages from the server.  It is the only
way (at least currently) that you can retrieve non-error status messages
when execution is successful.

To use the error handler, set the "odbc_err_handler" attribute on
your database handle to a reference to a subroutine that will act
as the error handler.  This subroutine will be passed two args, the
SQLSTATE and the error message.  If the subroutine returns 0, the
error message will be otherwise ignored.  If it returns non-zero,
the error message will be processed normally.  

The second function implemented is asynchronous execution.  It's only
useful for retrieving server messages with an error handler during an
execute() that takes a long time (such as a DBCC on a large database) ODBC
doesn't have the concept of a callback routine like Sybase's DBlib/CTlib
does, so asynchronous execution is needed to be able to get the server
messages before the SQL statement is done processing.

To use asynchronous execution, set the "odbc_async_exec" attribute on
your database handle to 1.  Not all ODBC drivers support asynchronous
execution.  To see if yours does, set odbc_async_exec to 1 and then check
it's value.  If the value is 1, your ODBC driver can do asynchronous
execution.  If the value is 0, your ODBC driver cannot.

Here's a sample script:

use strict;

use DBI;

sub err_handler {
  my ($state, $msg) = @_;
  # Strip out all of the driver ID stuff
  $msg =~ s/^(\[[\w\s]*\])+//;  
  print "===> state: $state msg: $msg\n";
  return 0;
}
my $dbh = DBI->connect("dbi:ODBC:TEST248", "sa", "********")
       || die "Can't connect: $DBI::errstr\n";

$dbh->{odbc_err_handler} = \&err_handler;
$dbh->{odbc_async_exec} = 1;
print "odbc_async_exec is: $dbh->{odbc_async_exec}\n";

my $sth;
$sth = $dbh->prepare("dbcc checkdb(model)") || die $dbh->errstr;
$sth->execute                               || die $dbh->errstr;
$sth->finish;
$dbh->disconnect;


Observations:

  - I've tested this on Sybase 11.0.3, MS SQL Server 6.5 and 7.0,
    Oracle 8.1.6 using Oracle 7.3 drivers.  I doubt any of this will be
    tremendously useful to Oracle users though...

  - ODBC seems to buffer the messages it makes available, so you'll get
    server messages in chunks.  This means there could be significant
    delays in getting messages from the server.  For example, if while
    running a DBCC, you could get a significant message just before
    the DBCC starts on a huge table.  Since ODBC is buffering the messages,
    you won't see that significant message until DBCC is done with the
    huge table (and possibly a few others) and fills the buffer.

  - Oracle's ODBC drivers do not seem to support asynchronous execution
    at all.  But that's OK, since I doubt Oracle generates any messages
    during execution...

  - A lot of the guts to implement the error handler was lifted wholesale
    from DBD:Sybase 0.21.  I don't even pretend to fully understand some
    of the stuff in this patch.  Thanks go to Michael Peppler for his work
    on DBD:Sybase, making this patch possible.

-- 
David Good                                         David.Good@stratasource.com

                 This space intentionally left blank.



--- dbdimp.c.orig	Wed Jun 14 14:31:48 2000
+++ dbdimp.c	Wed Jun 28 12:21:53 2000
@@ -327,9 +327,6 @@
     HSTMT hstmt = SQL_NULL_HSTMT;
     SV *errstr;
 
-    if (err_rc == SQL_SUCCESS && DBIS->debug<3)	/* nothing to do */
-	return;
-
     switch(DBIc_TYPE(imp_xxh)) {
 	case DBIt_ST:
 	    imp_sth = (struct imp_sth_st *)(imp_xxh);
@@ -342,6 +339,17 @@
 	default:
 	    croak("panic: dbd_error on bad handle type");
     }
+
+    /*
+     * If status is SQL_SUCCESS, there's no error, so we can just return.
+     * There may be status or other non-error messsages though.
+     * We want those messages if the debug level is set to at least 3.
+     * If an error handler is installed, let it decide what messages
+     * should or shouldn't be reported.
+     */
+    if (err_rc == SQL_SUCCESS && DBIS->debug < 3 && !imp_dbh->err_handler)
+	return; 
+
     hdbc = imp_dbh->hdbc;
     henv = imp_dbh->henv;
 
@@ -368,6 +376,50 @@
 			    ErrorMsg, sizeof(ErrorMsg)-1, &ErrorMsgLen
 			   )) == SQL_SUCCESS || rc == SQL_SUCCESS_WITH_INFO) {
 	    sv_setpvn(DBIc_STATE(imp_xxh), sqlstate, 5);
+	    /*
+	     * If there's an error handler, run it and see what it returns...
+	     * (lifted from DBD:Sybase 0.21)
+	     */
+
+	    if(imp_dbh->err_handler) {
+		dSP;
+		SV *sv, **svp;
+		HV *hv;
+		int retval, count;
+
+		ENTER;
+		SAVETMPS;
+		PUSHMARK(sp);
+
+		if (DBIS->debug >= 3)
+		    fprintf(DBILOGFP, "dbd_error: calling err_handler\n"); 
+
+		/* 
+		 * Here are the args to the error handler routine:
+		 *    1. sqlstate (string)
+		 *    2. ErrorMsg (string)
+		 *
+		 * That's it for now...
+		 */
+		XPUSHs(sv_2mortal(newSVpv(sqlstate, 0)));
+		XPUSHs(sv_2mortal(newSVpv(ErrorMsg, 0)));
+
+
+		PUTBACK;
+		if((count = perl_call_sv(imp_dbh->err_handler, G_SCALAR)) != 1)
+		    croak("An error handler can't return a LIST.");
+		SPAGAIN;
+		retval = POPi;
+
+		PUTBACK;
+		FREETMPS;
+		LEAVE;
+
+		/* If the called sub returns 0 then ignore this error */
+		if(retval == 0)
+		    continue;
+	    }
+
 	    if (SvCUR(errstr) > 0) {
 		sv_catpv(errstr, "\n");
 		/* JLU: attempt to get a reasonable error	*/
@@ -406,7 +458,7 @@
 	else henv = SQL_NULL_HENV;	/* done the top		*/
     }
 
-    if (err_rc != SQL_SUCCESS) {
+    if (err_rc != SQL_SUCCESS && err_rc != SQL_STILL_EXECUTING) {
 	if (what) {
 	    char buf[10];
 	    sprintf(buf, " err=%d", err_rc);
@@ -631,6 +683,23 @@
     imp_sth->RowCount = -1;
     imp_sth->eod = -1;
 
+    /* If AsyncExecute is set and AsyncType is SQL_AM_STATEMENT, we need to
+     * set the SQL_ATTR_ASYNC_ENABLE attribute.
+     */
+    if (imp_dbh->AsyncExecute && imp_dbh->AsyncType == SQL_AM_STATEMENT){
+	rc = SQLSetStmtAttr(imp_sth->hstmt,
+			    SQL_ATTR_ASYNC_ENABLE,
+			    (SQLPOINTER) SQL_ASYNC_ENABLE_ON,
+			    SQL_IS_UINTEGER
+			   );
+	if (!SQL_ok(rc)) {
+	    dbd_error(sth, rc, "st_prepare/SQLSetStmtAttr");
+	    SQLFreeStmt(imp_sth->hstmt, SQL_DROP);
+	    imp_sth->hstmt = SQL_NULL_HSTMT;
+	    return 0;
+	}
+    }
+
     DBIc_IMPSET_on(imp_sth);
     return 1;
 }
@@ -934,6 +1003,23 @@
 		imp_sth->hstmt);
 
     rc = SQLExecute(imp_sth->hstmt);
+
+    /*
+     * If asynchronous execution has been enabled, SQLExecute will
+     * return SQL_STILL_EXECUTING until it has finished.
+     * Grab whatever messages occur during execution...
+     */
+    while (rc == SQL_STILL_EXECUTING){
+	dbd_error(sth, rc, "st_execute/SQLExecute"); 
+
+	/* Wait a second so we don't loop too fast and bring the machine
+	 * to its knees
+	 */
+	sleep(1);
+	
+	rc = SQLExecute(imp_sth->hstmt);
+    }
+     
     /* patches to handle blobs better, via Jochen Wiedmann */
     while (rc == SQL_NEED_DATA) {
 	phs_t* phs;
@@ -956,11 +1042,16 @@
 	}
 	rc = SQL_NEED_DATA;  /*  So the loop continues ...  */
     }
-     
+
+    /* 
+     * Call dbd_error regardless of the value of rc so we can
+     * get any status messages that are desired.
+     */
+    dbd_error(sth, rc, "st_execute/SQLExecute"); 
     if (!SQL_ok(rc)) {
-	dbd_error(sth, rc, "st_execute/SQLExecute");
-	return -2;
+ 	return -2;
     }
+ 
 
     rc = SQLRowCount(imp_sth->hstmt, &imp_sth->RowCount);
     if (!SQL_ok(rc)) {
@@ -1664,13 +1755,118 @@
     STRLEN kl;
     STRLEN plen;
     char *key = SvPV(keysv,kl);
-    SV *cachesv = NULL;
+    SV *cachesv = NULL;  /* This never seems to be used?!? [dgood 6/16/00] */
     int on;
     UDWORD vParam;
     const db_params *pars;
 
-    if ((pars = S_dbOption(S_db_storeOptions, key, kl)) == NULL)
+    if ((pars = S_dbOption(S_db_storeOptions, key, kl)) == NULL) {
+
+	/* Here's where we put attributes that are *not* just */
+	/* SQLSetConnectOption attributes                     */
+
+	/* This was taken from DBD::Sybase 0.21 */
+	if (kl == 16 && strEQ(key, "odbc_err_handler")) {
+	    if(valuesv == &sv_undef) {
+		imp_dbh->err_handler = NULL;
+	    } else if(imp_dbh->err_handler == (SV*)NULL) {
+		imp_dbh->err_handler = newSVsv(valuesv);
+	    } else {
+		sv_setsv(imp_dbh->err_handler, valuesv);
+	    }
+	    return TRUE;
+	}
+	if (kl == 15 && strEQ(key, "odbc_async_exec")) {
+	    on = SvTRUE(valuesv);
+	    if(on) {
+		/* Only bother setting the attribute if it's not already set! */
+		if (imp_dbh->AsyncExecute == 1) 
+		    return TRUE;
+
+		/*
+		 * Determine which method of async execution this
+		 * driver allows -- per-connection or per-statement
+		 */
+		rc = SQLGetInfo(imp_dbh->hdbc, 
+				SQL_ASYNC_MODE, 
+				&imp_dbh->AsyncType,
+				sizeof(imp_dbh->AsyncType),
+				NULL
+			       );
+		/*
+		 * Normally, we'd do a if (!SQL_ok(rc)) ... here.
+		 * Unfortunately, if the driver doesn't support async
+		 * mode, it may return an error here.  There doesn't
+		 * seem to be any other way to check (other than doing
+		 * a special check for the SQLSTATE).  We'll just default
+		 * to doing nothing and not bother checking errors.
+		 */
+
+
+		if (imp_dbh->AsyncType == SQL_AM_CONNECTION){
+		    /*
+		     * Driver has per-connection async option.  Set it
+		     * now in the dbh.
+		     */
+		    if (DBIS->debug >= 2)
+			fprintf(DBILOGFP, 
+				"Supported AsyncType is SQL_AM_CONNECTION\n");
+		    rc = SQLSetConnectOption(imp_dbh->hdbc, 
+					     SQL_ATTR_ASYNC_ENABLE,
+					     SQL_ASYNC_ENABLE_ON
+					    );
+		    if (!SQL_ok(rc)) {
+			dbd_error(dbh, rc, "db_STORE/SQLSetConnectOption");
+			return FALSE;
+		    }
+		    imp_dbh->AsyncExecute = 1;
+		}
+		else if (imp_dbh->AsyncType == SQL_AM_STATEMENT){
+		    /*
+		     * Driver has per-statement async option.  Just set
+		     * AsyncExecute and the rest will be handled by 
+		     * dbd_st_prepare.
+		     */
+		    if (DBIS->debug >= 2)
+			fprintf(DBILOGFP, 
+				"Supported AsyncType is SQL_AM_STATEMENT\n");
+		    imp_dbh->AsyncExecute = 1;
+		}
+		else {   /* (imp_dbh->AsyncType == SQL_AM_NONE) */
+		    /*
+		     * We're out of luck.
+		     */
+		    if (DBIS->debug >= 2)
+			fprintf(DBILOGFP, 
+				"Supported AsyncType is SQL_AM_NONE\n");
+		    imp_dbh->AsyncExecute = 0;
+		    return FALSE;
+		}
+	    } else {
+		/* Only bother turning it off if it was previously set... */
+		if (imp_dbh->AsyncExecute == 1) {
+
+		    /* We only need to do anything here if the AsyncType is 
+		     * SQL_AM_CONNECTION since the per-statement async type
+		     * is turned on only when the statement handle is created.
+		     */
+		    if (imp_dbh->AsyncType == SQL_AM_CONNECTION){
+			rc = SQLSetConnectOption(imp_dbh->hdbc, 
+						 SQL_ATTR_ASYNC_ENABLE,
+						 SQL_ASYNC_ENABLE_OFF
+						);
+			if (!SQL_ok(rc)) {
+			    dbd_error(dbh, rc, "db_STORE/SQLSetConnectOption");
+			    return FALSE;
+			}
+		    }
+		}
+		imp_dbh->AsyncExecute = 0;
+	    }
+	    return TRUE;
+	}
 	return FALSE;
+    }
 
     switch(pars->fOption)
     {
@@ -1731,8 +1927,27 @@
 
     /* checking pars we need FAST */
 
-    if ((pars = S_dbOption(S_db_fetchOptions, key, kl)) == NULL)
-	return Nullsv;
+    if ((pars = S_dbOption(S_db_fetchOptions, key, kl)) == NULL) {
+
+	/* Here's where we put attributes that are *not* just */
+	/* SQLGetConnectOption attributes                     */
+
+	/* This was taken from DBD::Sybase 0.21 */
+	if (kl == 16 && strEQ(key, "odbc_err_handler")) {
+	    if(imp_dbh->err_handler) {
+		retsv = newSVsv(imp_dbh->err_handler);
+	    } else {
+		retsv = &sv_undef;
+	    }
+	}
+	if (kl == 15 && strEQ(key, "odbc_async_exec")) {
+	    if(imp_dbh->AsyncExecute)
+		retsv = newSViv(1);
+	    else
+		retsv = newSViv(0);
+	}
+	return retsv;
+    }
 
     /*
      * readonly, tracefile etc. isn't working yet. only AutoCommit supported.
--- dbdimp.h.orig	Wed Jun 14 14:31:55 2000
+++ dbdimp.h	Wed Jun 21 15:24:05 2000
@@ -27,6 +27,13 @@
     dbih_dbc_t com;		/* MUST be first element in structure	*/
     HENV henv;			/* copy from imp_drh for speed		*/
     HDBC hdbc;
+
+    SV *err_handler;
+
+    int		AsyncExecute;	/* Execute statements asynchronously */
+    SQLUINTEGER	AsyncType;      /* What type of async execution the driver
+                                 * supports
+				 */
 };
 
 
@@ -38,7 +45,7 @@
     HDBC       hdbc;		/* copy for speed	*/
     HSTMT      hstmt;
 
-	int        moreResults;	/* are there more results to fetch?	*/
+    int        moreResults;	/* are there more results to fetch?	*/
     int        done_desc;	/* have we described this sth yet ?	*/
 
     /* Input Details	*/


----- End forwarded message -----

-- 
David Good                                                    dave@dave.net

                 This space intentionally left blank.

