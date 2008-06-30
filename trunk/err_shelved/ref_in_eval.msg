From owner-perl5-porters@perl.org  Sun May 23 17:17:17 1999
Return-Path: <owner-perl5-porters@perl.org>
Received: from oink by toad.ig.co.uk (SMI-8.6/SMI-SVR4)
	id RAA03964; Sun, 23 May 1999 17:17:16 +0100
Received: from punt-11.mail.demon.net by oink with SMTP (PP) id <05597-3@oink>;
          Sun, 23 May 1999 17:16:14 +0100
Received: from punt-1.mail.demon.net by mailstore for timbo@ig.co.uk 
          id 927473893:10:18342:13; Sun, 23 May 99 15:38:13 GMT
Received: from defender.perl.org ([209.45.167.243]) by punt-1.mail.demon.net 
          id aa1126778; 23 May 99 15:37 GMT
Received: (from majordomo@localhost) 
          by defender.perl.org (8.9.3/8.9.3/Debian/GNU) id LAA25353 
          for perl5-porters-outgoing; Sun, 23 May 1999 11:35:47 -0400
Received: from crypt.compulink.co.uk (root@crypt.compulink.co.uk [194.153.28.27]) 
          by defender.perl.org (8.9.3/8.9.3/Debian/GNU) with SMTP id LAA25346 
          for <perl5-porters@perl.org>; Sun, 23 May 1999 11:35:42 -0400
Received: from crypt.compulink.co.uk (hv@localhost [127.0.0.1]) 
          by crypt.compulink.co.uk (8.6.12/8.6.9) with ESMTP id QAA00032;
          Sun, 23 May 1999 16:35:07 +0100
Message-Id: <199905231535.QAA00032@crypt.compulink.co.uk>
To: perl5-porters@perl.org
cc: hv@crypt0.demon.co.uk
Reply-to: hv@crypt0.demon.co.uk
Subject: [PATCH 5.005_56] name PL_in_eval bits
Date: Sun, 23 May 1999 16:35:07 +0100
From: Hugo van der Sanden <hv@crypt.compulink.co.uk>
Sender: owner-perl5-porters@perl.org
Precedence: bulk
X-Loop: Perl5-Porters
Status: RO
Content-Length: 4206
Lines: 145

The attached patch names the bit values used for PL_in_eval, prompted
by the possibility that regexp evals might need an extra bit.

It may be worth checking the places that do a simple boolean test on
PL_in_eval, to see whether they should more correctly be checking
(PL_in_eval & EVAL_INEVAL) rather than (PL_in_eval != EVAL_NULL);
this particularly may affect those cases when yywarn() sets
EVAL_WARNONLY.

I'm not entirely sure that scope.h is the best place for the defines,
but I couldn't think of a better.

This patch changes no behaviour, and all tests still pass here.

Hugo
--- scope.h.old	Mon Feb 15 00:39:04 1999
+++ scope.h	Sun May 23 16:26:56 1999
@@ -188,4 +188,10 @@
    
 #define CATCH_GET	(PL_top_env->je_mustcatch)
 #define CATCH_SET(v)	(PL_top_env->je_mustcatch = (v))
-   
+
+/* flag bits for PL_in_eval */
+#define EVAL_NULL 0			/* not in an eval */
+#define EVAL_INEVAL 1		/* some enclosing scope is an eval */
+#define EVAL_WARNONLY 2		/* used by yywarn() when calling yyerror() */
+#define EVAL_KEEPERR 4		/* set by perl_call_sv if G_KEEPERR */
+
--- op.c.old	Sun Feb 28 21:42:19 1999
+++ op.c	Sun May 23 16:12:00 1999
@@ -104,7 +104,7 @@
 	    SV *msg = sv_2mortal(
 			newSVpvf("(Did you mean $ or @ instead of %c?)\n",
 				 type == OP_ENTERSUB ? '&' : '%'));
-	    if (PL_in_eval & 2)
+	    if (PL_in_eval & EVAL_WARNONLY)
 		warn("%_", msg);
 	    else if (PL_in_eval)
 		sv_catsv(GvSV(PL_errgv), msg);
@@ -1721,7 +1721,8 @@
 {
     dTHR;
     if (PL_in_eval) {
-	PL_eval_root = newUNOP(OP_LEAVEEVAL, ((PL_in_eval & 4) ? OPf_SPECIAL : 0), o);
+	PL_eval_root = newUNOP(OP_LEAVEEVAL,
+		((PL_in_eval & EVAL_KEEPERR) ? OPf_SPECIAL : 0), o);
 	PL_eval_start = linklist(PL_eval_root);
 	PL_eval_root->op_next = 0;
 	peep(PL_eval_start);
@@ -3936,7 +3937,7 @@
 	    if (strEQ(s, "BEGIN")) {
 		char *not_safe =
 		    "BEGIN not safe after errors--compilation aborted";
-		if (PL_in_eval & 4)
+		if (PL_in_eval & EVAL_KEEPERR)
 		    croak(not_safe);
 		else {
 		    /* force display of errors found but not reported */
--- perl.c.old	Mon Mar  1 03:30:47 1999
+++ perl.c	Sun May 23 16:12:21 1999
@@ -1274,9 +1274,9 @@
 	    PUSHEVAL(cx, 0, 0);
 	    PL_eval_root = PL_op;             /* Only needed so that goto works right. */
 	    
-	    PL_in_eval = 1;
+	    PL_in_eval = EVAL_INEVAL;
 	    if (flags & G_KEEPERR)
-		PL_in_eval |= 4;
+		PL_in_eval |= EVAL_KEEPERR;
 	    else
 		sv_setpv(ERRSV,"");
 	}
--- pp_ctl.c.old	Thu Feb 18 20:31:00 1999
+++ pp_ctl.c	Sun May 23 16:13:51 1999
@@ -1330,7 +1330,7 @@
 	SV **newsp;
 
 	if (message) {
-	    if (PL_in_eval & 4) {
+	    if (PL_in_eval & EVAL_KEEPERR) {
 		SV **svp;
 		STRLEN klen = strlen(message);
 		
@@ -2591,7 +2591,7 @@
     AV* comppadlist;
     I32 i;
 
-    PL_in_eval = 1;
+    PL_in_eval = EVAL_INEVAL;
 
     PUSHMARK(SP);
 
@@ -2670,7 +2670,7 @@
     SvREFCNT_dec(PL_rs);
     PL_rs = newSVpv("\n", 1);
     if (saveop && saveop->op_flags & OPf_SPECIAL)
-	PL_in_eval |= 4;
+	PL_in_eval |= EVAL_KEEPERR;
     else
 	sv_setpv(ERRSV,"");
     if (yyparse() || PL_error_count || !PL_eval_root) {
@@ -3092,7 +3092,7 @@
     PUSHEVAL(cx, 0, 0);
     PL_eval_root = PL_op;		/* Only needed so that goto works right. */
 
-    PL_in_eval = 1;
+    PL_in_eval = EVAL_INEVAL;
     sv_setpv(ERRSV,"");
     PUTBACK;
     return DOCATCH(PL_op->op_next);
--- toke.c.old	Sun Feb 28 21:40:03 1999
+++ toke.c	Sun May 23 16:16:27 1999
@@ -6342,9 +6342,9 @@
 {
     dTHR;
     --PL_error_count;
-    PL_in_eval |= 2;
+    PL_in_eval |= EVAL_WARNONLY;
     yyerror(s);
-    PL_in_eval &= ~2;
+    PL_in_eval &= ~EVAL_WARNONLY;
     return 0;
 }
 
@@ -6407,7 +6407,7 @@
 		(int)PL_multi_open,(int)PL_multi_close,(long)PL_multi_start);
         PL_multi_end = 0;
     }
-    if (PL_in_eval & 2)
+    if (PL_in_eval & EVAL_WARNONLY)
 	warn("%_", msg);
     else if (PL_in_eval)
 	sv_catsv(ERRSV, msg);
--- util.c.old	Mon Feb 15 02:28:30 1999
+++ util.c	Sun May 23 16:19:04 1999
@@ -2882,7 +2882,7 @@
     PL_start_env.je_mustcatch = TRUE;
     PL_top_env  = &PL_start_env;
 
-    PL_in_eval = FALSE;
+    PL_in_eval = EVAL_NULL;	/* ~(EVAL_INEVAL|EVAL_WARNONLY|EVAL_KEEPERR) */
     PL_restartop = 0;
 
     PL_statname = NEWSV(66,0);

