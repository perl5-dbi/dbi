From owner-perl5-porters@perl.org  Wed Aug  4 19:22:43 1999
Return-Path: <owner-perl5-porters@perl.org>
Received: from oink by toad.ig.co.uk (SMI-8.6/SMI-SVR4)
	id TAA17154; Wed, 4 Aug 1999 19:22:42 +0100
Received: from punt-21.mail.demon.net by oink with SMTP (PP) id <18339-4@oink>;
          Wed, 4 Aug 1999 19:21:42 +0100
Received: from punt-2.mail.demon.net by mailstore for timbo@ig.co.uk 
          id 933790392:20:21708:11; Wed, 04 Aug 99 18:13:12 GMT
Received: from defender.perl.org ([209.45.167.243]) by punt-2.mail.demon.net 
          id aa2021630; 4 Aug 99 18:13 GMT
Received: (from majordomo@localhost) 
          by defender.perl.org (8.9.3/8.9.3/Debian/GNU) id OAA31539 
          for perl5-porters-outgoing; Wed, 4 Aug 1999 14:12:38 -0400
Received: from imr1.srv.na.deuba.com (imr1.srv.na.deuba.com [165.250.91.54]) 
          by defender.perl.org (8.9.3/8.9.3/Debian/GNU) with ESMTP id OAA31533 
          for <perl5-porters@perl.org>; Wed, 4 Aug 1999 14:12:36 -0400
Received: by imr1.srv.na.deuba.com id OAA06501;
          Wed, 4 Aug 1999 14:12:31 -0400 (EDT)
Received: from bmr2-e1.srv.na.deuba.com(165.250.66.247) 
          by imr1.srv.na.deuba.com via mail (V2.1/2.1) id xma006478;
          Wed, 4 Aug 99 14:12:26 -0400
Received: from dbrelay2.srv.na.deuba.com by bmr2-e1.srv.na.deuba.com 
          id OAA28420; Wed, 4 Aug 1999 14:12:24 -0400 (EDT)
Received: from db.com by dbrelay2.srv.na.deuba.com id OAA29992;
          Wed, 4 Aug 1999 14:11:36 -0400 (EDT)
Received: by db.com (sSMTP sendmail emulation); Wed, 4 Aug 1999 14:12:23 -0400
Date: Wed, 4 Aug 1999 14:12:23 -0400
From: Joshua N Pritikin <joshua.pritikin@db.com>
To: perl5-porters@perl.org
Subject: perl_call_pv("Carp::croak", ...) [5.5.58]
Message-ID: <19990804141222.J4209@eq1062.wks.na.deuba.com>
Reply-To: Joshua N Pritikin <joshua.pritikin@db.com>
Mail-Followup-To: perl5-porters@perl.org
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
X-Mailer: Mutt 0.95.5i
Sender: owner-perl5-porters@perl.org
Precedence: bulk
X-Loop: Perl5-Porters
Status: RO
Content-Length: 1014
Lines: 32

I use the attached code to invoke Carp::croak from C.  It has been
working fine until 5.5.58.  It appears that it fails if Carp::Heavy
has not already been loaded.  If Carp::Heavy is not already loaded,
then perl_call_pv actually returns, then I panic and exit.  Any
ideas?  Should I code I up a small test case as an XS module?

static void Event_croak(const char* pat, ...) {
    STRLEN n_a;
    dSP;
    SV *msg;
    va_list args;
    perl_require_pv("Carp.pm");
    va_start(args, pat);
    msg = NEWSV(0,0);
    sv_vsetpvfn(msg, pat, strlen(pat), &args, Null(SV**), 0, 0);
    va_end(args);
    SvREADONLY_on(msg);
    SAVEFREESV(msg);
    PUSHMARK(SP);
    XPUSHs(msg);
    PUTBACK;
    perl_call_pv("Carp::croak", G_DISCARD);
    PerlIO_puts(PerlIO_stderr(), "panic: Carp::croak failed\n");
    (void)PerlIO_flush(PerlIO_stderr());
    my_failure_exit();
}

Thanks.

-- 
"Never ascribe to malice that which can be explained by stupidity."
                            via, but not speaking for Deutsche Bank

