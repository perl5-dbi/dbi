From perl5-changes-return-9816-Tim.Bunce=pobox.com@perl.org  Sun Jan  4 07:32:30 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i047VbnH056390
	for <timbo@localhost>; Sun, 4 Jan 2004 07:32:29 GMT
	(envelope-from perl5-changes-return-9816-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Sun, 04 Jan 2004 07:32:29 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1AcsDY-0002mR-SW;
	Sat, 03 Jan 2004 20:17:53 +0000
Received: from [207.8.214.2] (helo=icicle.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1AcsDY-0002mR-SW
	for pobox@dbi.demon.co.uk; Sat, 03 Jan 2004 20:17:52 +0000
Received: from icicle.pobox.com (localhost [127.0.0.1])
	by icicle.pobox.com (Postfix) with ESMTP id 6F55E2ABC
	for <pobox@dbi.demon.co.uk>; Sat,  3 Jan 2004 15:17:52 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by icicle.pobox.com (Postfix) with ESMTP id 4ED592AB0
	for <Tim.Bunce@pobox.com>; Sat,  3 Jan 2004 15:17:52 -0500 (EST)
Received: from onion.perl.org (onion.develooper.com [63.251.223.166])
	by icicle.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Sat,  3 Jan 2004 15:17:50 -0500 (EST)
Received: (qmail 21904 invoked by uid 1005); 3 Jan 2004 20:17:47 -0000
Mailing-List: contact perl5-changes-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:perl5-changes@perl.org>
List-Help: <mailto:perl5-changes-help@perl.org>
List-Unsubscribe: <mailto:perl5-changes-unsubscribe@perl.org>
List-Subscribe: <mailto:perl5-changes-subscribe@perl.org>
Delivered-To: mailing list perl5-changes@perl.org
Received: (qmail 21888 invoked by uid 76); 3 Jan 2004 20:17:46 -0000
Delivered-To: perl5-changes@perl.org
Date: Sat, 3 Jan 2004 12:15:00 -0800
Message-Id: <200401032015.i03KF0UU028201@smtp3.ActiveState.com>
From: Rafael Garcia-Suarez <rgarciasuarez@free.fr>
To: "Anybody And Everybody" <perl5-changes@perl.org>
Subject: Change 22051: Upgrade to Time::HiRes 1.54
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=1.1 required=7.0 tests=CARRIAGE_RETURNS,SPAM_PHRASE_00_01 version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Status: RO
Content-Length: 7435
Lines: 272

Change 22051 by rgs@rgs-home on 2004/01/03 19:51:02

	Upgrade to Time::HiRes 1.54

Affected files ...

... //depot/perl/MANIFEST#1124 edit
... //depot/perl/ext/Time/HiRes/Changes#14 edit
... //depot/perl/ext/Time/HiRes/HiRes.pm#30 edit
... //depot/perl/ext/Time/HiRes/HiRes.xs#38 edit
... //depot/perl/ext/Time/HiRes/hints/solaris.pl#1 add

Differences ...

==== //depot/perl/MANIFEST#1124 (text) ====
Index: perl/MANIFEST
--- perl/MANIFEST#1123~22007~	Tue Dec 30 08:04:47 2003
+++ perl/MANIFEST	Sat Jan  3 11:51:02 2004
@@ -749,6 +749,7 @@
 ext/Time/HiRes/hints/dynixptx.pl	Hint for Time::HiRes for named architecture
 ext/Time/HiRes/hints/irix.pl	Hint for Time::HiRes for named architecture
 ext/Time/HiRes/hints/sco.pl	Hints for Time::HiRes for named architecture
+ext/Time/HiRes/hints/solaris.pl	Hints for Time::HiRes for named architecture
 ext/Time/HiRes/hints/svr4.pl	Hints for Time::HiRes for named architecture
 ext/Time/HiRes/HiRes.pm		Time::HiRes extension
 ext/Time/HiRes/HiRes.xs		Time::HiRes extension

==== //depot/perl/ext/Time/HiRes/Changes#14 (text) ====
Index: perl/ext/Time/HiRes/Changes
--- perl/ext/Time/HiRes/Changes#13~21567~	Tue Oct 28 00:48:06 2003
+++ perl/ext/Time/HiRes/Changes	Sat Jan  3 11:51:02 2004
@@ -1,5 +1,15 @@
 Revision history for Perl extension Time::HiRes.
 
+1.54
+	- Solaris: like Tru64 (dec_osf) also Solaris need -lrt for nanosleep
+
+1.53
+	- Windows: higher resolution time() by using the Windows
+	  performance counter API, from Jan Dubois and Anton Shcherbinin.
+	  The exact new higher resolution depends on the hardware,
+	  but it should be quite a bit better than using the basic
+	  Windows timers.
+
 1.52
 	- In AIX (v?) with perl 5.6.1 the HiRes.t can hang after
 	  the subtest 18.  No known analysis nor fix, but added

==== //depot/perl/ext/Time/HiRes/HiRes.pm#30 (text) ====
Index: perl/ext/Time/HiRes/HiRes.pm
--- perl/ext/Time/HiRes/HiRes.pm#29~21567~	Tue Oct 28 00:48:06 2003
+++ perl/ext/Time/HiRes/HiRes.pm	Sat Jan  3 11:51:02 2004
@@ -15,7 +15,7 @@
 		 d_usleep d_ualarm d_gettimeofday d_getitimer d_setitimer
 		 d_nanosleep);
 	
-$VERSION = '1.52';
+$VERSION = '1.54';
 $XS_VERSION = $VERSION;
 $VERSION = eval $VERSION;
 
@@ -343,7 +343,7 @@
 
 Copyright (c) 1996-2002 Douglas E. Wegscheid.  All rights reserved.
 
-Copyright (c) 2002,2003 Jarkko Hietaniemi.  All rights reserved.
+Copyright (c) 2002,2003,2004 Jarkko Hietaniemi.  All rights reserved.
 
 This program is free software; you can redistribute it and/or modify
 it under the same terms as Perl itself.

==== //depot/perl/ext/Time/HiRes/HiRes.xs#38 (text) ====
Index: perl/ext/Time/HiRes/HiRes.xs
--- perl/ext/Time/HiRes/HiRes.xs#37~19898~	Mon Jun 30 22:54:58 2003
+++ perl/ext/Time/HiRes/HiRes.xs	Sat Jan  3 11:51:02 2004
@@ -1,6 +1,7 @@
 #ifdef __cplusplus
 extern "C" {
 #endif
+#define PERL_NO_GET_CONTEXT
 #include "EXTERN.h"
 #include "perl.h"
 #include "XSUB.h"
@@ -18,10 +19,34 @@
 }
 #endif
 
+#ifndef NOOP
+#    define NOOP (void)0
+#endif
+#ifndef dNOOP
+#    define dNOOP extern int Perl___notused
+#endif
+
 #ifndef aTHX_
 #    define aTHX_
 #    define pTHX_
-#endif         
+#    define dTHX dNOOP
+#endif
+
+#ifdef START_MY_CXT
+#  ifndef MY_CXT_CLONE
+#    define MY_CXT_CLONE                                                \
+	dMY_CXT_SV;							\
+	my_cxt_t *my_cxtp = (my_cxt_t*)SvPVX(newSV(sizeof(my_cxt_t)-1));\
+	Copy(INT2PTR(my_cxt_t*, SvUV(my_cxt_sv)), my_cxtp, 1, my_cxt_t); \
+	sv_setuv(my_cxt_sv, PTR2UV(my_cxtp))
+#  endif
+#else
+#    define START_MY_CXT static my_cxt_t my_cxt;
+#    define dMY_CXT	 dNOOP
+#    define MY_CXT_INIT	 NOOP
+#    define MY_CXT_CLONE NOOP
+#    define MY_CXT	 my_cxt
+#endif
 
 #ifndef NVTYPE
 #   if defined(USE_LONG_DOUBLE) && defined(HAS_LONG_DOUBLE)
@@ -110,8 +135,11 @@
 
 #include "const-c.inc"
 
-#if !defined(HAS_GETTIMEOFDAY) && defined(WIN32)
-#define HAS_GETTIMEOFDAY
+#ifdef WIN32
+
+#ifndef HAS_GETTIMEOFDAY
+#   define HAS_GETTIMEOFDAY
+#endif
 
 /* shows up in winsock.h?
 struct timeval {
@@ -125,6 +153,17 @@
     FILETIME		ft_val;
 } FT_t;
 
+#define MY_CXT_KEY "Time::HiRes_" XS_VERSION
+
+typedef struct {
+    unsigned long run_count;
+    unsigned __int64 base_ticks;
+    unsigned __int64 tick_frequency;
+    FT_t base_systime_as_filetime;
+} my_cxt_t;
+
+START_MY_CXT
+
 /* Number of 100 nanosecond units from 1/1/1601 to 1/1/1970 */
 #ifdef __GNUC__
 #define Const64(x) x##LL
@@ -135,13 +174,34 @@
 
 /* NOTE: This does not compute the timezone info (doing so can be expensive,
  * and appears to be unsupported even by glibc) */
-int
-gettimeofday (struct timeval *tp, void *not_used)
+
+/* dMY_CXT needs a Perl context and we don't want to call PERL_GET_CONTEXT
+   for performance reasons */
+
+#undef gettimeofday
+#define gettimeofday(tp, not_used) _gettimeofday(aTHX_ tp, not_used)
+
+static int
+_gettimeofday(pTHX_ struct timeval *tp, void *not_used)
 {
+    dMY_CXT;
+
+    unsigned __int64 ticks;
     FT_t ft;
 
-    /* this returns time in 100-nanosecond units  (i.e. tens of usecs) */
-    GetSystemTimeAsFileTime(&ft.ft_val);
+    if (MY_CXT.run_count++) {
+        QueryPerformanceCounter((LARGE_INTEGER*)&ticks);
+        ticks -= MY_CXT.base_ticks;
+        ft.ft_i64 = MY_CXT.base_systime_as_filetime.ft_i64
+                    + 10000000i64 * (ticks / MY_CXT.tick_frequency)
+                    +(10000000i64 * (ticks % MY_CXT.tick_frequency)) / MY_CXT.tick_frequency;
+    }
+    else {
+        QueryPerformanceFrequency((LARGE_INTEGER*)&MY_CXT.tick_frequency);
+        QueryPerformanceCounter((LARGE_INTEGER*)&MY_CXT.base_ticks);
+        GetSystemTimeAsFileTime(&MY_CXT.base_systime_as_filetime.ft_val);
+        ft.ft_i64 = MY_CXT.base_systime_as_filetime.ft_i64;
+    }
 
     /* seconds since epoch */
     tp->tv_sec = (long)((ft.ft_i64 - EPOCH_BIAS) / Const64(10000000));
@@ -153,6 +213,15 @@
 }
 #endif
 
+#if defined(WIN32) && !defined(ATLEASTFIVEOHOHFIVE)
+static unsigned int
+sleep(unsigned int t)
+{
+    Sleep(t*1000);
+    return 0;
+}
+#endif
+
 #if !defined(HAS_GETTIMEOFDAY) && defined(VMS)
 #define HAS_GETTIMEOFDAY
 
@@ -605,7 +674,7 @@
 #ifdef HAS_GETTIMEOFDAY
 
 static int
-myU2time(UV *ret)
+myU2time(pTHX_ UV *ret)
 {
   struct timeval Tp;
   int status;
@@ -618,6 +687,9 @@
 static NV
 myNVtime()
 {
+#ifdef WIN32
+    dTHX;
+#endif
   struct timeval Tp;
   int status;
   status = gettimeofday (&Tp, NULL);
@@ -631,15 +703,29 @@
 PROTOTYPES: ENABLE
 
 BOOT:
+{
+#ifdef MY_CXT_KEY
+  MY_CXT_INIT;
+#endif
 #ifdef ATLEASTFIVEOHOHFIVE
 #ifdef HAS_GETTIMEOFDAY
-{
-  UV auv[2];
-  hv_store(PL_modglobal, "Time::NVtime", 12, newSViv(PTR2IV(myNVtime)), 0);
-  if (myU2time(auv) == 0)
-    hv_store(PL_modglobal, "Time::U2time", 12, newSViv((IV) auv[0]), 0);
-}
+  {
+    UV auv[2];
+    hv_store(PL_modglobal, "Time::NVtime", 12, newSViv(PTR2IV(myNVtime)), 0);
+    if (myU2time(aTHX_ auv) == 0)
+      hv_store(PL_modglobal, "Time::U2time", 12, newSViv((IV) auv[0]), 0);
+  }
+#endif
 #endif
+}
+
+#if defined(USE_ITHREADS) && defined(MY_CXT_KEY)
+
+void
+CLONE(...)
+    CODE:
+    MY_CXT_CLONE;
+
 #endif
 
 INCLUDE: const-xs.inc

==== //depot/perl/ext/Time/HiRes/hints/solaris.pl#1 (text) ====
Index: perl/ext/Time/HiRes/hints/solaris.pl
--- /dev/null	Tue May  5 13:32:27 1998
+++ perl/ext/Time/HiRes/hints/solaris.pl	Sat Jan  3 11:51:02 2004
@@ -0,0 +1,3 @@
+# needs to explicitly link against librt to pull in nanosleep
+$self->{LIBS} = ['-lrt'];
+
End of Patch.


