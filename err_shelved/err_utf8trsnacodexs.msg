From perl-unicode-return-2087-Tim.Bunce=pobox.com@perl.org  Fri Aug  8 18:30:31 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id h78HU65r059847
	for <timbo@localhost>; Fri, 8 Aug 2003 18:30:30 +0100 (BST)
	(envelope-from perl-unicode-return-2087-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 08 Aug 2003 18:30:30 +0100 (BST)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 19lAqh-0003IH-Em;
	Fri, 08 Aug 2003 17:16:19 +0000
Received: from [207.106.49.21] (helo=wink.pobox.com)
	by punt-3.mail.demon.net with esmtp id 19lAqh-0003IH-Em
	for pobox@dbi.demon.co.uk; Fri, 08 Aug 2003 17:16:19 +0000
Received: from wink.pobox.com (localhost [127.0.0.1])
	by wink.pobox.com (Postfix) with ESMTP id 7A07010048
	for <pobox@dbi.demon.co.uk>; Fri,  8 Aug 2003 13:16:05 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [64.70.54.95])
	by wink.pobox.com (Postfix) with SMTP id EB0B7FD57
	for <Tim.Bunce@pobox.com>; Fri,  8 Aug 2003 13:15:59 -0400 (EDT)
Received: (qmail 22852 invoked by uid 1005); 8 Aug 2003 17:15:58 -0000
Mailing-List: contact perl-unicode-help@perl.org; run by ezmlm
Precedence: bulk
list-help: <mailto:perl-unicode-help@perl.org>
list-unsubscribe: <mailto:perl-unicode-unsubscribe@perl.org>
list-post: <mailto:perl-unicode@perl.org>
Delivered-To: mailing list perl-unicode@perl.org
Received: (qmail 22837 invoked by uid 76); 8 Aug 2003 17:15:57 -0000
Delivered-To: perl-unicode@perl.org
Received-SPF: unknown
Date: Sat, 9 Aug 2003 02:15:48 +0900
Subject: Re: Encode from XS
Content-Type: text/plain; charset=US-ASCII; format=flowed
Mime-Version: 1.0 (Apple Message framework v552)
Cc: perl-unicode@perl.org
To: Simon Cozens <simon@simon-cozens.org>
From: Dan Kogai <dankogai@dan.co.jp>
In-Reply-To: <87brv0mbk8.fsf@alibi.simon-cozens.org>
Message-Id: <F4150ECF-C9C3-11D7-BE7D-000393AE4244@dan.co.jp>
Content-Transfer-Encoding: 7bit
X-Mailer: Apple Mail (2.552)
X-SMTPD: qpsmtpd/0.27-dev, http://develooper.com/code/qpsmtpd/
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=-2.3 required=7.0 tests=CARRIAGE_RETURNS,IN_REP_TO,QUOTED_EMAIL_TEXT,SPAM_PHRASE_00_01,USER_AGENT_APPLEMAIL version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Status: RO
Content-Length: 945
Lines: 27

On Saturday, Aug 9, 2003, at 00:08 Asia/Tokyo, Simon Cozens wrote:
> This is sad and I ought to know the answer, but...
>
> Can someone give me a few quick examples of creating Encode::XS objects
> to do simple transcoding, from XS?

You should check the source of PerlIO::encoding 
(ext/PerlIO/encoding/encoding.xs) to see how to do so via XS.  But I 
don't think you'd call it simple.  Let me quote a few lines from there;

         PUSHMARK(sp);
         XPUSHs(e->enc);
         XPUSHs(e->dataSV);
         XPUSHs(e->chk);
         PUTBACK;
         if (call_method("decode", G_SCALAR) != 1) {
             Perl_die(aTHX_ "panic: decode did not return a value");
         }
         SPAGAIN;
         uni = POPs;

See?  It does exactly what you would call an ordinary perl 
(sub|method)s from XS; you push arguments into the stack, call_method() 
and pop the result.  In other words, there is no shortcut -- yet.

Dan the Encode Maintainer


