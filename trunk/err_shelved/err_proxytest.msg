From timbo@dansat.data-plan.com  Wed May 14 14:41:47 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.6/8.12.6) with ESMTP id h4EDda3A043838
	for <timbo@localhost>; Wed, 14 May 2003 14:41:47 +0100 (BST)
	(envelope-from timbo@dansat.data-plan.com)
Received: from pop3.mail.demon.net [194.217.242.39]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Wed, 14 May 2003 14:41:47 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1052910735:10:26872:56; Wed, 14 May 2003 11:12:15 GMT
Received: from puzzle.pobox.com ([207.106.49.20]) by punt-1.mail.demon.net
           id aa1027917; 14 May 2003 11:12 GMT
Received: from puzzle.pobox.com (localhost [127.0.0.1])
	by puzzle.pobox.com (Postfix) with ESMTP id 2D0A226C404
	for <Tim.Bunce@data-plan.com>; Wed, 14 May 2003 07:10:45 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from mail01.svc.cra.dublin.eircom.net (mail01.svc.cra.dublin.eircom.net [159.134.118.17])
	by puzzle.pobox.com (Postfix) with SMTP id 3CAC726C2F8
	for <Tim.Bunce@pobox.com>; Wed, 14 May 2003 07:10:44 -0400 (EDT)
Received: (qmail 33834 messnum 121761 invoked from network[159.134.164.133/p133.as1.limerick1.eircom.net]); 14 May 2003 11:10:42 -0000
Received: from p133.as1.limerick1.eircom.net (HELO dansat.data-plan.com) (159.134.164.133)
  by mail01.svc.cra.dublin.eircom.net (qp 33834) with SMTP; 14 May 2003 11:10:42 -0000
Received: from dansat.data-plan.com (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.6/8.12.6) with ESMTP id h4EBAk2f043654;
	Wed, 14 May 2003 12:10:46 +0100 (BST)
	(envelope-from timbo@dansat.data-plan.com)
Received: (from timbo@localhost)
	by dansat.data-plan.com (8.12.6/8.12.6/Submit) id h4EBAkH4043653;
	Wed, 14 May 2003 12:10:46 +0100 (BST)
Date: Wed, 14 May 2003 12:10:41 +0100
From: Tim Bunce <Tim.Bunce@pobox.com>
To: Brian McCauley <nobull@cpan.org>
Cc: "Steven N. Hirsch" <shirsch@adelphia.net>, Tim Bunce <Tim.Bunce@pobox.com>
Subject: Re: (Fwd) Re: Announce: DBI 1.36 ** RELEASE CANDIDATE 1 **
Message-ID: <20030514111041.GY29922@dansat.data-plan.com>
References: <Pine.LNX.4.44.0305131812150.2200-100000@atx.fast.net> <u94r3xlxbo.fsf@wcl-l.bham.ac.uk>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <u94r3xlxbo.fsf@wcl-l.bham.ac.uk>
User-Agent: Mutt/1.4i
Status: RO
Content-Length: 945
Lines: 24

On Wed, May 14, 2003 at 09:57:47AM +0100, Brian McCauley wrote:
> 
> It is beginning to look more and more like something in my stuff has
> interacted with other changes between 1.35 and 1.36RC1.
> 
> Having fixed the typo you found I've just run my patched 1.35
> DBD::Proxy against it's own server and an old one, in all three
> proxy_lazy_prepare modes ('0','1',undef) and with and without reading
> NUM_OF_FIELDS between the prepare() and the execute().  It worked in
> all 12 cases.
> 
> Anyhow lets hope 1.36RC2 works.  When 1.36 is out I'll produce a
> tested set of patches against that and refrain from letting anyone see
> my untested code.

Sounds good.

Certainly it would be helpful to improve the test suite.
I'd like to see a t/foo.t that starts a server, sets DBI_AUTOPROXY,
then executes t/10examp.t. It could then repeat that using different
options in DBI_AUTOPROXY ("dbi:Proxy(proxy_foo=bar):...") to test
other modes.

Tim.

