From stas@stason.org  Tue Jan 20 07:35:33 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i0K7Z6Fj081147
	for <timbo@localhost>; Tue, 20 Jan 2004 07:35:33 GMT
	(envelope-from stas@stason.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Tue, 20 Jan 2004 07:35:33 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1Aikr1-0002Iu-IF;
	Tue, 20 Jan 2004 01:38:55 +0000
Received: from [208.58.1.193] (helo=boggle.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1Aikr1-0002Iu-IF
	for pobox@dbi.demon.co.uk; Tue, 20 Jan 2004 01:38:55 +0000
Received: from boggle.pobox.com (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id BF366172FA
	for <pobox@dbi.demon.co.uk>; Mon, 19 Jan 2004 20:38:54 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 85D14172E7
	for <Tim.Bunce@pobox.com>; Mon, 19 Jan 2004 20:38:54 -0500 (EST)
Received: from mail.logilune.com (erato.logilune.com [195.154.174.52])
	by boggle.pobox.com (Postfix) with ESMTP
	for <Tim.Bunce@pobox.com>; Mon, 19 Jan 2004 20:38:53 -0500 (EST)
Received: from stason.org (localhost.logilune.com [127.0.0.1])
	by mail.logilune.com (Postfix) with ESMTP
	id 9C2EB78D14; Tue, 20 Jan 2004 02:38:50 +0100 (CET)
Message-ID: <400C86A8.8020504@stason.org>
Date: Mon, 19 Jan 2004 17:38:48 -0800
From: Stas Bekman <stas@stason.org>
Organization: Hope, Humanized
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.5) Gecko/20031010
X-Accept-Language: en-us, en, he, ru
MIME-Version: 1.0
To: Tim Bunce <Tim.Bunce@pobox.com>
Cc: dbi-users@perl.org
Subject: Re: Proxy: (Fwd) [patch] make Storable thread-safe
References: <20040119122323.GJ70289@dansat.data-plan.com>
In-Reply-To: <20040119122323.GJ70289@dansat.data-plan.com>
Content-Type: text/plain; charset=us-ascii; format=flowed
Content-Transfer-Encoding: 7bit
Status: RO
Content-Length: 1076
Lines: 25

Tim Bunce wrote:
> This is relevant to any brave people trying to use DBD::Proxy or
> DBI::ProxyServer on unix in threaded mode or windows (where threads
> are used to emulate forks).

Not because they use Storable, but because they need to be aware of the 
PL_modglobal issues on perl_clone? In which case they probably should read 
Jan's original notes:
http://www.xray.mpe.mpg.de/mailing-lists/perl5-porters/2003-12/msg00994.html

> p.s. Thanks Stas!

;)

I'm still collecting bits and showcases and once I'm done I'll publish an 
article on this topic. I still have a few unresolved mysteries in mp2 
connected to the perl_clone issue, as they happen only on win32 and i'm 
running on linux, I'm not very advancing at guessing the cause.

__________________________________________________________________
Stas Bekman            JAm_pH ------> Just Another mod_perl Hacker
http://stason.org/     mod_perl Guide ---> http://perl.apache.org
mailto:stas@stason.org http://use.perl.org http://apacheweek.com
http://modperlbook.org http://apache.org   http://ticketmaster.com


From dbi-users-return-21628-Tim.Bunce=pobox.com@perl.org  Fri Jan 16 14:58:56 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i0GEwPFl040187
	for <timbo@localhost>; Fri, 16 Jan 2004 14:58:55 GMT
	(envelope-from dbi-users-return-21628-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 16 Jan 2004 14:58:55 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1AhV4F-0001m7-DH;
	Fri, 16 Jan 2004 14:35:23 +0000
Received: from [207.8.214.3] (helo=puzzle.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1AhV4F-0001m7-DH
	for pobox@dbi.demon.co.uk; Fri, 16 Jan 2004 14:35:23 +0000
Received: from puzzle.pobox.com (localhost [127.0.0.1])
	by puzzle.pobox.com (Postfix) with ESMTP id AB74A361CC
	for <pobox@dbi.demon.co.uk>; Fri, 16 Jan 2004 09:35:22 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by puzzle.pobox.com (Postfix) with ESMTP id 8E85936185
	for <Tim.Bunce@pobox.com>; Fri, 16 Jan 2004 09:35:22 -0500 (EST)
Received: from onion.perl.org (onion.develooper.com [63.251.223.166])
	by puzzle.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Fri, 16 Jan 2004 09:35:19 -0500 (EST)
Received: (qmail 77666 invoked by uid 1005); 16 Jan 2004 14:35:16 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 77647 invoked by uid 76); 16 Jan 2004 14:35:16 -0000
Received: from qmailr@one.develooper.com (HELO ran-out.mx.develooper.com) (64.81.84.115) by onion.perl.org (qpsmtpd/0.26) with SMTP; Fri, 16 Jan 2004 06:35:16 -0800
Received: (qmail 22234 invoked by uid 225); 16 Jan 2004 14:35:13 -0000
Delivered-To: dbi-users@perl.org
Received: (qmail 22222 invoked by uid 507); 16 Jan 2004 14:35:12 -0000
Received: from uk.radan.com (HELO styx.radan.com) (195.166.67.76) by one.develooper.com (qpsmtpd/0.27-dev) with SMTP; Fri, 16 Jan 2004 06:34:41 -0800
Received: from unknown(195.166.67.78) by styx.radan.com via csmap 	 id 6e4cddf0_4831_11d8_8d7d_0002b3cb43e0_7294;	Fri, 16 Jan 2004 14:36:55 +0000 (GMT)
Organisation: Radan Computational Ltd., Bath, UK.
Phone: +44 1225 320320   Fax: +44 1225 320311
Web: http://www.radan.com/
Received: from uk.radan.com (tangaroa.uk.radan.com [172.16.50.61])	by sockeye.uk.radan.com (8.9.1b+Sun/8.9.1) with ESMTP id OAA28946;	Fri, 16 Jan 2004 14:32:20 GMT
Message-ID: <4007F6CC.2000909@uk.radan.com>
Date: Fri, 16 Jan 2004 14:35:56 +0000
From: Steve Hay <steve.hay@uk.radan.com>
User-Agent: Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.4) Gecko/20030624 Netscape/7.1 (ax)
X-Accept-Language: en-gb, en, en-us
MIME-Version: 1.0
To: Kurt George Gjerde <kurt.gjerde@intermedia.uib.no>
Cc: dev@perl.apache.org, dbi-users@perl.org
Subject: Re: [mp2] DBI failing thread test (win32)
References: <4007C386.4030604@intermedia.uib.no>
In-Reply-To: <4007C386.4030604@intermedia.uib.no>
Content-Type: text/plain
Content-Transfer-Encoding: 7bit
X-NAIMIME-Disclaimer: 1
X-NAIMIME-Modified: 1
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=-1.4 required=7.0 tests=CARRIAGE_RETURNS,EXCUSE_16,IN_REP_TO,QUOTED_EMAIL_TEXT,REFERENCES,SPAM_PHRASE_05_08,SUPERLONG_LINE,USER_AGENT,USER_AGENT_MOZILLA_UA,X_ACCEPT_LANG version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Status: RO
Content-Length: 5019
Lines: 158

[I'm posting this to dbi-users for their attention too, since the second 
test script at least looks like a DBI/DBD problem, definitely not mod_perl.]

Hi Kurt,

Kurt George Gjerde wrote:

>Hi,
>
>Not really mod_perl but maybe the same issues as the recent Storable. 
>This was experienced on win32 with the following line-up: Apache/2.0.48 
>(Win32) mod_perl/1.99_12-dev Perl/v5.8.2 + DBI/v1.39 DBD/mysql/v2.9002.
>
>The DBI_01.pm (mp2 handler) below complains about "Attempt to free 
>unreferenced scalar: SV 0x280bac00 at E:/usr/site/lib/DBI.pm line 626" 
>under "heavy" load (try 'ab -n 100 -c 5' or more).
>
I had to try a much heavier load than that to break it ("ab -n 1000 -c 
100" did the trick), but I don't see the error anywhere -- just a popup 
application window.

Here's the stack trace (I'm using apache-2.0.48, perl-5.8.3-RC1, 
DBI-1.40, DBD-mysql-2.9003):
=====
apr_pollset_add(apr_pollset_t * 0x00000000, const apr_pollfd_t * 
0x0012f9f8) line 384 + 6 bytes
write_request(connection * 0x00910068) line 803
start_connect(connection * 0x00910068) line 1285 + 9 bytes
test() line 1671 + 23 bytes
main(int 6, const char * const * 0x00322520) line 2191
mainCRTStartup() line 338 + 17 bytes
KERNEL32! 77e814c7()
=====

This is a different failure to the others.  It could just be an 
out-of-memory error (although I don't see any tasks eating significant 
chunks of memory in Task Manager)?

>
>I was unable to recreate the same warnings outside mod_perl 
>(dbi_01_test.pl) but got "free to wrong pool" and segfault instead. This 
>is just by opening and closing a connection so it's a bit strange, since 
>I can do this inside mp2 without any complaints (except when there's 
>many threads operating).
>
>You need to put in your own db details in order for these tests to work 
>(I used the mysql driver so it may also be specific to that one). Steve, 
>do you have any chance to test this?
>
dbi_01_test.pl does fail for me in the same way that you describe.  It 
looks like the usual problem this time too:

=====
VMem::Free(void * 0x019c0fa0) line 208 + 3 bytes
CPerlHost::Free(void * 0x019c0fa0) line 59 + 34 bytes
PerlMemFree(IPerlMem * 0x00222434, void * 0x019c0fa0) line 302
Perl_safesysfree(void * 0x019c0fa0) line 140 + 26 bytes
perl_destruct(interpreter * 0x0022425c) line 544 + 20 bytes
RunPerl(int 2, char * * 0x00223da8, char * * 0x00222c58) line 206 + 12 bytes
main(int 2, char * * 0x00223da8, char * * 0x00222c58) line 18 + 18 bytes
PERL! mainCRTStartup + 227 bytes
KERNEL32! 77e814c7()
=====

- Steve

>
>BTW: I also found threading problems with XML::LibXML and was able to 
>reproduce it in pure perl (generating "free to wrong pool" and "attempt 
>to free unreferenced scalar"). I've posted this to the perl-xml list. 
>Looks like this is a win32 specific problem as well. 
>http://aspn.activestate.com/ASPN/Mail/Message/perl-xml/1972902
>
>
>-Kurt.
>
>
>- dbi_01_test.pl (pure perl) -
>
>   #!/usr/bin/perl
>   use strict;
>   use threads;
>   use DBI;
>
>   my $DB_DATASOURCE = 'your_datasource';
>   my $DB_USER       = 'username';
>   my $DB_PASSWORD   = 'password';
>
>   my $t1 = threads->new(\&dbsub);
>   $t1->join();
>
>   sub dbsub {
>     my $dbh = DBI->connect( $DB_DATASOURCE, $DB_USER, $DB_PASSWORD );
>     $dbh->disconnect();
>   }
>   __END__
>
>
>- DBI_01.pm (mp2 handler) -
>
>   package MyApache::Test::DBI_01;
>
>   use strict;
>   use warnings FATAL => 'all', NONFATAL => 'redefine';
>   use Apache::Const -compile => qw(OK);
>   use Apache::Log;
>   use DBI;
>
>   my $DB_DATASOURCE = 'your_datasource';
>   my $DB_USER       = 'username';
>   my $DB_PASSWORD   = 'password';
>
>   my $I;
>   my $DBH;
>
>   sub handler {
>     my $r = shift;
>     my $data = {};
>     $I++;
>     print "DBI_01 [$I]\n";
>
>     unless ($DBH) {
>       $DBH = DBI->connect( $DB_DATASOURCE, $DB_USER, $DB_PASSWORD );
>     }
>
>     unless ($DBH) {
>       $r->log_error(__PACKAGE__ . ': ' . $DBI::errstr);
>       print "FAILED!\n";
>     } else {
>       print "OK\n";
>
>       my $sth = $DBH->prepare("select * from session");
>       $sth->execute();
>       print $sth->rows() . "\n";
>       $sth->finish();
>
>     }
>
>     print "done.\n";
>     return Apache::OK;
>   }
>   1;
>   __END__
>
>
>
>
>  
>




------------------------------------------------
Radan Computational Ltd.

The information contained in this message and any files transmitted with it are confidential and intended for the addressee(s) only.  If you have received this message in error or there are any problems, please notify the sender immediately.  The unauthorized use, disclosure, copying or alteration of this message is strictly forbidden.  Note that any views or opinions presented in this email are solely those of the author and do not necessarily represent those of Radan Computational Ltd.  The recipient(s) of this message should check it and any attached files for viruses: Radan Computational will accept no liability for any damage caused by any virus transmitted by this email.


From jand@ActiveState.com  Wed Jan 28 07:55:38 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i0S7Xi7i041218
	for <timbo@localhost>; Wed, 28 Jan 2004 07:55:38 GMT
	(envelope-from jand@ActiveState.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Wed, 28 Jan 2004 07:55:38 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1Alhia-0001KR-Jv;
	Wed, 28 Jan 2004 04:54:24 +0000
Received: from [208.58.1.193] (helo=boggle.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1Alhia-0001KR-Jv
	for pobox@dbi.demon.co.uk; Wed, 28 Jan 2004 04:54:24 +0000
Received: from boggle.pobox.com (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 2AC6729A22
	for <pobox@dbi.demon.co.uk>; Tue, 27 Jan 2004 23:54:23 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 7E2C329AB5
	for <Tim.Bunce@pobox.com>; Tue, 27 Jan 2004 23:54:21 -0500 (EST)
Received: from smtp2.ActiveState.com (gw.activestate.com [209.17.183.249])
	by boggle.pobox.com (Postfix) with ESMTP
	for <Tim.Bunce@pobox.com>; Tue, 27 Jan 2004 23:53:46 -0500 (EST)
Received: from smtp3.ActiveState.com (latte.ActiveState.com [192.168.4.252] (may be forged))
	by smtp2.ActiveState.com (8.12.10/8.12.10) with ESMTP id i0S4LekK020310;
	Tue, 27 Jan 2004 20:24:09 -0800
	(envelope-from jand@ActiveState.com)
Received: from tofino.activestate.com (tofino.activestate.com [192.168.3.138])
	by smtp3.ActiveState.com (8.12.9/8.12.9) with SMTP id i0S3WcQN010543;
	Tue, 27 Jan 2004 19:32:38 -0800
From: Jan Dubois <jand@ActiveState.com>
To: Tim Bunce <Tim.Bunce@pobox.com>
Cc: Steve Hay <steve.hay@uk.radan.com>
Subject: Re: [mp2] DBI failing thread test (win32)
Date: Tue, 27 Jan 2004 19:32:38 -0800
Message-ID: <h9ae1019k89h7hpe54u2gsm548pp36nf7v@4ax.com>
References: <20040126T104807sgoeldner@cpan.org> <i3ra1010hs5cfdkbig2r5pi8fbhsek8e88@4ax.com> <4007F6CC.2000909@uk.radan.com> <20040127224913.GE38394@dansat.data-plan.com>
In-Reply-To: <20040127224913.GE38394@dansat.data-plan.com>
X-Mailer: Forte Agent 1.8/32.548
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: 7bit
Status: RO
X-Status: A
Content-Length: 2454
Lines: 85

On Tue, 27 Jan 2004 22:49:13 +0000, Tim Bunce <Tim.Bunce@pobox.com>
wrote:

Hi Tim,

>Any chance you could take a look at the DBI.xs code in relation to
>the issues you described here:
>
>http://www.xray.mpe.mpg.de/mailing-lists/perl5-porters/2003-12/msg00994.html
>
>The PL_modglobal code, around line 150, was originally contributed
>by ActiveState (Murray Nesbitt) and I've no way to check it but it
>looks like there may be issues:

I looked at the DBI code a bit, and I _think_ the PL_modglobal code
should be working correctly.  When an interpreter is cloned, DBI->CLONE
is invoked, which in turn will call _clone_dbis().  That one calls
dbi_bootinit() which reinitializes the PL_modglobal entry via
INIT_PERINTERP.  So each interpreter should end up with its own data
area allocated from the correct pool.

>http://www.mail-archive.com/dev@perl.apache.org/msg06050.html

>A patch would be wonderful, but failing that some detailed directions
>would be great.
>
>Any chance you can help?

Could you try the PERL_TRACK_MEMPOOL patch I sent last week or so to
p5p?  That should allow you to reproduce the problem on Unix too (if you
use threading).  If you then just use the part of my second patch that
changes SV allocation from using the arenas to always allocating from
the heap, then you _might_ catch the wrong allocation at an earlier
point.  Don't bother with any other bits from my second patch as it is
very experimental and doesn't work quite right.

I can't find those messages in the xray archive, but they seem to be on
ASPN (but mangled by HTML conversion):

http://aspn.activestate.com/ASPN/Mail/Message/perl5-porters/1979065

The second one is this one:

http://aspn.activestate.com/ASPN/Mail/Message/perl5-porters/1979886

The only part that you should use are the first 2 hunks from sv.c:

diff -u sv.c.orig sv.c
--- sv.c.orig	Mon Jan 19 19:45:53 2004
+++ sv.c	Thu Jan 22 11:18:24 2004
@@ -170,6 +170,21 @@
     } STMT_END
 
 
+#if defined(PERL_IMPLICIT_CONTEXT) && defined(PERL_TRACK_MEMPOOL)
+STATIC SV*
+S_new_SV()
+{
+    SV* sv = safemalloc(sizeof(SV));
+    SvANY(sv) = 0;
+    SvREFCNT(sv) = 1;
+    SvFLAGS(sv) = 0;
+    return sv;
+}
+
+#  define new_SV(p) (p)=S_new_SV()
+#  define del_SV(p) safefree((char*)p)
+#else
+
 /* new_SV(): return a new, empty SV head */
 
 #ifdef DEBUG_LEAKING_SCALARS
@@ -253,6 +268,7 @@
 
 #endif /* DEBUGGING */
 
+#endif
 
 /*
 =head1 SV Manipulation Functions
End of patch

Cheers,
-Jan


From steve.hay@uk.radan.com  Wed Jan 28 14:32:31 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i0SETi3o044424
	for <timbo@localhost>; Wed, 28 Jan 2004 14:32:31 GMT
	(envelope-from steve.hay@uk.radan.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Wed, 28 Jan 2004 14:32:31 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1AllpJ-0006xF-Jt;
	Wed, 28 Jan 2004 09:17:39 +0000
Received: from [208.58.1.193] (helo=boggle.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1AllpJ-0006xF-Jt
	for pobox@dbi.demon.co.uk; Wed, 28 Jan 2004 09:17:37 +0000
Received: from boggle.pobox.com (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 437BA2ADA4
	for <pobox@dbi.demon.co.uk>; Wed, 28 Jan 2004 04:17:36 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 6B2752A5D1
	for <Tim.Bunce@pobox.com>; Wed, 28 Jan 2004 04:17:34 -0500 (EST)
Received: from styx.radan.com (uk.radan.com [217.205.167.84])
	by boggle.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Wed, 28 Jan 2004 04:16:52 -0500 (EST)
Received: from unknown(217.205.167.82) by styx.radan.com via csmap 
	 id f967c5b8_5172_11d8_914c_0002b3cb43e0_7153;
	Wed, 28 Jan 2004 09:18:46 +0000 (GMT)
Organisation: Radan Computational Ltd., Bath, UK.
Phone: +44 1225 320320   Fax: +44 1225 320311
Web: http://www.radan.com/
Received: from uk.radan.com (tangaroa.uk.radan.com [172.16.50.61])
	by sockeye.uk.radan.com (8.9.1b+Sun/8.9.1) with ESMTP id JAA27529;
	Wed, 28 Jan 2004 09:13:44 GMT
Message-ID: <40177E26.8070302@uk.radan.com>
Date: Wed, 28 Jan 2004 09:17:26 +0000
From: Steve Hay <steve.hay@uk.radan.com>
User-Agent: Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.4) Gecko/20030624 Netscape/7.1 (ax)
X-Accept-Language: en-gb, en, en-us
MIME-Version: 1.0
To: Jan Dubois <jand@ActiveState.com>
Cc: Tim Bunce <Tim.Bunce@pobox.com>, rlippan@remotelinux.com
Subject: Re: [mp2] DBI failing thread test (win32)
References: <20040126T104807sgoeldner@cpan.org> <i3ra1010hs5cfdkbig2r5pi8fbhsek8e88@4ax.com> <4007F6CC.2000909@uk.radan.com> <20040127224913.GE38394@dansat.data-plan.com> <h9ae1019k89h7hpe54u2gsm548pp36nf7v@4ax.com>
In-Reply-To: <h9ae1019k89h7hpe54u2gsm548pp36nf7v@4ax.com>
Content-Type: text/plain
Content-Transfer-Encoding: 7bit
X-NAIMIME-Disclaimer: 1
X-NAIMIME-Modified: 1
Status: RO
Content-Length: 4684
Lines: 140

Hi All,

I now believe that it could be the DBD-mysql driver, rather than DBI 
itself, which might have a problem with threads on Win32, hence I'm 
copying Rudy Lippan too.

When I originally tried the DBI test program that fails under a threaded 
Perl on Win32 (the first test program posted here: 
http://www.mail-archive.com/dev@perl.apache.org/msg06050.html), I was 
using the DBD-mysql driver.  As I said in that mail, I was able to 
reproduce the "Free to wrong pool" problem.

In the light of Jan's comments below that DBI itself should be OK, I've 
tried the same test program again using a different DBD driver.  Using 
DBD-ODBC on an ODBC data source which accesses the same MySQL database 
as the same user, the test program no longer fails.

My setup:  WinXP SP1, MSVC++ 6 SP5, Perl 5.8.3, DBI 1.40, MySQL 
4.0.16-max-nt, DBD-mysql 2.9003, MyODBC 3.5106, DBD-ODBC 1.06.

Rudy, is there any chance you could have a look at this too?  Jan's 
PERL_TRACK_MEMPOOL patch referred to below should help you reproduce the 
problem in non-Microsoft land if you don't have a Win32 machine available.

Here's a link to Jan's patch on the xray archive (which doesn't 
HTML-mangle things like the ASPN archive does): 
http://www.xray.mpe.mpg.de/mailing-lists/perl5-porters/2004-01/msg00748.html

Cheers,
- Steve


Jan Dubois wrote:

>On Tue, 27 Jan 2004 22:49:13 +0000, Tim Bunce <Tim.Bunce@pobox.com>
>wrote:
>
>Hi Tim,
>
>  
>
>>Any chance you could take a look at the DBI.xs code in relation to
>>the issues you described here:
>>
>>http://www.xray.mpe.mpg.de/mailing-lists/perl5-porters/2003-12/msg00994.html
>>
>>The PL_modglobal code, around line 150, was originally contributed
>>by ActiveState (Murray Nesbitt) and I've no way to check it but it
>>looks like there may be issues:
>>    
>>
>
>I looked at the DBI code a bit, and I _think_ the PL_modglobal code
>should be working correctly.  When an interpreter is cloned, DBI->CLONE
>is invoked, which in turn will call _clone_dbis().  That one calls
>dbi_bootinit() which reinitializes the PL_modglobal entry via
>INIT_PERINTERP.  So each interpreter should end up with its own data
>area allocated from the correct pool.
>
>  
>
>>http://www.mail-archive.com/dev@perl.apache.org/msg06050.html
>>    
>>
>
>  
>
>>A patch would be wonderful, but failing that some detailed directions
>>would be great.
>>
>>Any chance you can help?
>>    
>>
>
>Could you try the PERL_TRACK_MEMPOOL patch I sent last week or so to
>p5p?  That should allow you to reproduce the problem on Unix too (if you
>use threading).  If you then just use the part of my second patch that
>changes SV allocation from using the arenas to always allocating from
>the heap, then you _might_ catch the wrong allocation at an earlier
>point.  Don't bother with any other bits from my second patch as it is
>very experimental and doesn't work quite right.
>
>I can't find those messages in the xray archive, but they seem to be on
>ASPN (but mangled by HTML conversion):
>
>http://aspn.activestate.com/ASPN/Mail/Message/perl5-porters/1979065
>
>The second one is this one:
>
>http://aspn.activestate.com/ASPN/Mail/Message/perl5-porters/1979886
>
>The only part that you should use are the first 2 hunks from sv.c:
>
>diff -u sv.c.orig sv.c
>--- sv.c.orig	Mon Jan 19 19:45:53 2004
>+++ sv.c	Thu Jan 22 11:18:24 2004
>@@ -170,6 +170,21 @@
>     } STMT_END
> 
> 
>+#if defined(PERL_IMPLICIT_CONTEXT) && defined(PERL_TRACK_MEMPOOL)
>+STATIC SV*
>+S_new_SV()
>+{
>+    SV* sv = safemalloc(sizeof(SV));
>+    SvANY(sv) = 0;
>+    SvREFCNT(sv) = 1;
>+    SvFLAGS(sv) = 0;
>+    return sv;
>+}
>+
>+#  define new_SV(p) (p)=S_new_SV()
>+#  define del_SV(p) safefree((char*)p)
>+#else
>+
> /* new_SV(): return a new, empty SV head */
> 
> #ifdef DEBUG_LEAKING_SCALARS
>@@ -253,6 +268,7 @@
> 
> #endif /* DEBUGGING */
> 
>+#endif
> 
> /*
> =head1 SV Manipulation Functions
>End of patch
>
>Cheers,
>-Jan
>




------------------------------------------------
Radan Computational Ltd.

The information contained in this message and any files transmitted with it are confidential and intended for the addressee(s) only.  If you have received this message in error or there are any problems, please notify the sender immediately.  The unauthorized use, disclosure, copying or alteration of this message is strictly forbidden.  Note that any views or opinions presented in this email are solely those of the author and do not necessarily represent those of Radan Computational Ltd.  The recipient(s) of this message should check it and any attached files for viruses: Radan Computational will accept no liability for any damage caused by any virus transmitted by this email.


