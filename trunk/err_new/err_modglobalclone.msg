From perl5-porters-return-86721-Tim.Bunce=pobox.com@perl.org  Tue Dec 30 07:38:18 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id hBU7bOnG023888
	for <timbo@localhost>; Tue, 30 Dec 2003 07:38:17 GMT
	(envelope-from perl5-porters-return-86721-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Tue, 30 Dec 2003 07:38:17 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1Ab8yh-0002Ev-5j;
	Tue, 30 Dec 2003 01:47:24 +0000
Received: from [208.58.1.193] (helo=boggle.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1Ab8yh-0002Ev-5j
	for pobox@dbi.demon.co.uk; Tue, 30 Dec 2003 01:47:23 +0000
Received: from boggle.pobox.com (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id DCE8D32DE14
	for <pobox@dbi.demon.co.uk>; Mon, 29 Dec 2003 20:47:22 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 058D632DE1E
	for <Tim.Bunce@pobox.com>; Mon, 29 Dec 2003 20:47:21 -0500 (EST)
Received: from onion.perl.org (onion.develooper.com [63.251.223.166])
	by boggle.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Mon, 29 Dec 2003 20:47:04 -0500 (EST)
Received: (qmail 15799 invoked by uid 1005); 30 Dec 2003 01:46:58 -0000
Mailing-List: contact perl5-porters-help@perl.org; run by ezmlm
Precedence: bulk
list-help: <mailto:perl5-porters-help@perl.org>
list-unsubscribe: <mailto:perl5-porters-unsubscribe@perl.org>
list-post: <mailto:perl5-porters@perl.org>
X-List-Archive: <http://nntp.perl.org/group/perl.perl5.porters/86721>
Delivered-To: mailing list perl5-porters@perl.org
Received: (qmail 15779 invoked by uid 76); 30 Dec 2003 01:46:58 -0000
Delivered-To: perl5-porters@perl.org
From: Jan Dubois <jand@ActiveState.com>
To: Stas Bekman <stas@stason.org>, Arthur Bergman <sky@nanisky.com>
Cc: The Perl5 Porters Mailing List <perl5-porters@perl.org>
Subject: Re: XS modules having problems with CLONE and ithreads unless PERL_NO_GET_CONTEXT is defined
Date: Mon, 29 Dec 2003 17:44:17 -0800
Message-ID: <r5l1vv00ca033k7a06d40fgei1ion91rnp@4ax.com>
References: <3FCDAC86.8070907@stason.org>
In-Reply-To: <3FCDAC86.8070907@stason.org>
X-Mailer: Forte Agent 1.8/32.548
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: 7bit
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=-0.2 required=7.0 tests=CARRIAGE_RETURNS,IN_REP_TO,REFERENCES,SPAM_PHRASE_00_01 version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Content-Length: 1925
Lines: 50

On Wed, 03 Dec 2003 01:27:34 -0800, Stas Bekman <stas@stason.org> wrote:

>I've been working on Example::CLONE to have a fully working demo 
>implementation of the CLONE function, to show when this function is needed, 
>how to write a possess method, tests, etc. Eventually it should land in the 
>threads.pod or around it. You can look at what I've done so far:
>http://apache.org/~stas/Example-CLONE-0.01.tar.gz

Thanks for the sample code!

You should probably also mention that every module that stores
per-interpreter data in PL_modglobal may need to "clone" it in
the CLONE method as well.

This is especially true for modules that use MY_CXT_INIT to allocate
the per-interpreter storage.  It allocates the buffer as the PVX of
an untracked SV and then just stores the pointer as a UV.  The SV is
freed when the interpreter is destructed.

perl_clone() will copy the UV ptr in PL_modglobal, but if the first
interpreter is destroyed before the second one, then the PL_modglobal
entry in the second interpreter points to freed memory.

I would suggest that we add this macro to perl.h:

#define MY_CXT_CLONE                                                    \
	dMY_CXT_SV;							\
	my_cxt_t *my_cxtp = (my_cxt_t*)SvPVX(newSV(sizeof(my_cxt_t)-1));\
	Copy(INT2PTR(my_cxt_t, SvUV(my_cxt_sv)), my_extp, 1, my_cxt_t); \
	sv_setuv(my_cxt_sv, PTR2UV(my_cxtp))

and then recommend that each module using MY_CXT_INIT calls this macro in
an XS CLONE method such as:

void
CLONE(...)
    CODE:
    MY_CXT_CLONE;

I noticed that both the 're' and the 'Storable' core modules store data in
PL_modglobal.  At least 're' needs to use MY_CXT_CLONE.  I haven't looked
closely at 'Storable' to see if it handles interpreter cloning correctly or
not (it uses its own PL_modglobal handling macros).

I can send a patch for perl.h and re.xs (and Devel::PPPort.pm) unless someone
has a better idea how this should be handled.

Cheers,
-Jan


