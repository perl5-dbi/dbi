From perl5-porters-return-69761-Tim.Bunce=pobox.com@perl.org  Thu Dec 12 22:35:27 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.6/8.12.6) with ESMTP id gBCMYmb5000123
	for <timbo@localhost>; Thu, 12 Dec 2002 22:35:27 GMT
	(envelope-from perl5-porters-return-69761-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.22]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Thu, 12 Dec 2002 22:35:27 +0000 (GMT)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1039729881:20:12781:5; Thu, 12 Dec 2002 21:51:21 GMT
Received: from icicle.pobox.com ([66.220.15.208]) by punt-2.mail.demon.net
           id aa2011906; 12 Dec 2002 21:50 GMT
Received: from icicle.pobox.com (localhost [127.0.0.1])
	by icicle.pobox.com (Postfix) with ESMTP id 4F45123E28
	for <Tim.Bunce@data-plan.com>; Thu, 12 Dec 2002 16:50:55 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [64.70.54.95])
	by icicle.pobox.com (Postfix) with SMTP id 6747C23E15
	for <Tim.Bunce@pobox.com>; Thu, 12 Dec 2002 16:50:54 -0500 (EST)
Received: (qmail 89370 invoked by uid 1005); 12 Dec 2002 21:49:36 -0000
Mailing-List: contact perl5-porters-help@perl.org; run by ezmlm
Precedence: bulk
list-help: <mailto:perl5-porters-help@perl.org>
list-unsubscribe: <mailto:perl5-porters-unsubscribe@perl.org>
list-post: <mailto:perl5-porters@perl.org>
Delivered-To: mailing list perl5-porters@perl.org
Received: (qmail 89327 invoked by uid 76); 12 Dec 2002 21:49:35 -0000
Received: from exim@plum.flirble.org (HELO plum.flirble.org) (195.40.6.20) by onion.perl.org (qpsmtpd/0.20) with SMTP; 2002-12-12 21:49:35Z
Received: from gr.189.18.176.dial.global.net.uk ([80.189.18.176] helo=Bagpuss.unfortu.net)	by plum.flirble.org with asmtp (Exim 3.20 #3)	id 18MbD1-000LjS-00	for perl5-porters@perl.org; Thu, 12 Dec 2002 21:49:31 +0000
Received: from nick by Bagpuss.unfortu.net with local (Exim 3.22 #1 (Debian))	id 18Mb9C-0000F6-00; Thu, 12 Dec 2002 21:45:34 +0000
Date: Thu, 12 Dec 2002 21:45:34 +0000
To: John Peacock <jpeacock@rowman.com>
Cc: Rafael Garcia-Suarez <rgarciasuarez@free.fr>, perl5-porters@perl.org
Subject: Re: [PATCH] operation on `PL_na' may be undefined
Message-ID: <20021212214533.GI311@Bagpuss.unfortu.net>
References: <20021210195917.GJ288@Bagpuss.unfortu.net> <3DF64F1A.5050407@rowman.com> <20021211161647.39b89b14.rgarciasuarez@free.fr> <3DF767C0.1020103@rowman.com>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <3DF767C0.1020103@rowman.com>
User-Agent: Mutt/1.4i
From: Nicholas Clark <nick@unfortu.net>
X-SMTPD: qpsmtpd/0.20, http://develooper.com/code/qpsmtpd/
Status: RO
Content-Length: 1410
Lines: 50

Sorry about the delay in replying to the original question.
On Wed, Dec 11, 2002 at 11:28:48AM -0500, John Peacock wrote:
> Rafael Garcia-Suarez wrote:
> >%_ : placeholder for an SV that will get stringified. See sv_vcatpvfn() in 
> >sv.c.
> >I can't find doc on this in the perl sources, but there a small paragraph
> >about it in the Cozens & Jenness.

I can't find any docs either. In fact, a straight grep on %_ in the
current sources is most unrewarding.

> Neat!  Is it supported in 5.005???

Well, I had a grep in the 5.004_04 sources and it's in there quite a lot,
such as:

    if (in_eval & 2)
        warn("%_", msg);
    else if (in_eval)
        sv_catsv(GvSV(errgv), msg);

so I wondered what had happened to them all. The same piece of code is now:

    if (PL_in_eval & EVAL_WARNONLY)
        Perl_warn(aTHX_ "%"SVf, msg);
    else
        qerror(msg);

with this in perl.h

#ifndef SVf
#  ifdef CHECK_FORMAT
#    define SVf "p"
#  else
#    define SVf "_"
#  endif
#endif

That doesn't seem to be in Devel::PPort (yet - patches welcome I guess)

I wonder how many parts of the perl core can be reduced slightly in size
by changing %s SvPV_nolen(sv) to %_ sv.
This would have the beneficial side effect of making the non-error code path
more direct, which might have a slight speed gain.

It's not in 5.003_07's sources, but I don't think anyone really supports that
any more.

Nicholas Clark


