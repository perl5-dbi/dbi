From timbo@dansat.data-plan.com  Thu Dec  4 07:34:11 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id hB47Y2mu066844
	for <timbo@localhost>; Thu, 4 Dec 2003 07:34:11 GMT
	(envelope-from timbo@dansat.data-plan.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Thu, 04 Dec 2003 07:34:11 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1ARgSK-0000Hi-9X;
	Wed, 03 Dec 2003 23:30:53 +0000
Received: from [208.58.1.194] (helo=integer.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1ARgSK-0000Hi-9X
	for pobox@dbi.demon.co.uk; Wed, 03 Dec 2003 23:30:53 +0000
Received: from integer.pobox.com (localhost[127.0.0.1])
	by integer.pobox.com (Postfix) with ESMTP id B42051D049C
	for <pobox@dbi.demon.co.uk>; Wed,  3 Dec 2003 18:30:51 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost[127.0.0.1])
	by integer.pobox.com (Postfix) with ESMTP id 7CB961CFEB5
	for <Tim.Bunce@pobox.com>; Wed,  3 Dec 2003 18:30:51 -0500 (EST)
Received: from mail06.svc.cra.dublin.eircom.net (mail06.svc.cra.dublin.eircom.net[159.134.118.22])
	by integer.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Wed,  3 Dec 2003 18:30:50 -0500 (EST)
Received: (qmail 12583 messnum 241083 invoked from network[213.94.228.233/unknown]); 3 Dec 2003 23:30:39 -0000
Received: from unknown (HELO dansat.data-plan.com) (213.94.228.233)
  by mail06.svc.cra.dublin.eircom.net (qp 12583) with SMTP; 3 Dec 2003 23:30:39 -0000
Received: from dansat.data-plan.com (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id hB3NUfmo064642;
	Wed, 3 Dec 2003 23:30:41 GMT
	(envelope-from timbo@dansat.data-plan.com)
Received: (from timbo@localhost)
	by dansat.data-plan.com (8.12.9/8.12.9/Submit) id hB3NUeqU064641;
	Wed, 3 Dec 2003 23:30:40 GMT
Date: Wed, 3 Dec 2003 23:30:40 +0000
From: Tim Bunce <Tim.Bunce@pobox.com>
To: shlomit.afgin@weizmann.ac.il
Cc: Tim.Bunce@pobox.com
Subject: Re: upgrading to modperl2 & apache2 DBI 1.38
Message-ID: <20031203233040.GB64591@dansat.data-plan.com>
References: <Pine.SOL.4.40_heb2.09.0312031154260.16814-110000@clever.weizmann.ac.il>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <Pine.SOL.4.40_heb2.09.0312031154260.16814-110000@clever.weizmann.ac.il>
User-Agent: Mutt/1.4i
Status: RO
Content-Length: 1479
Lines: 42

Thanks. I'll look into it.

Tim.

On Wed, Dec 03, 2003 at 12:00:19PM +0200, Afgin Shlomit wrote:
> Thanks you for your help.
> 
> The problem was that I initilize %attr with "" insteade of () in the
> command below.
> DBI->connect($data_source, $username, $auth, \%attr);
> 
> It's seem that new version more strict, because it work this way
> in older versions.
> 
> Thanks again,
> 	Shlomit.

> Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
> Delivered-To: mailing list dbi-users@perl.org
> Delivered-To: dbi-users@perl.org
> Date: Mon, 1 Dec 2003 19:20:02 +0000
> From: Tim Bunce <Tim.Bunce@pobox.com>
> To: shlomit.afgin@weizmann.ac.il
> Cc: dbi-users@perl.org
> Subject: Re: upgrading to modperl2 & apache2 DBI 1.38
> In-Reply-To: <Pine.SOL.4.40_heb2.09.0312011111500.25767-100000@clever.weizmann.ac.il>
> 
> On Mon, Dec 01, 2003 at 11:14:16AM +0200, Afgin Shlomit wrote:
> > I install Apache 2.0.48 and modperl 1.99_10 I moved scripts that run okay
> > before with older versions. When I run my script I get the error:
> > an't use string ("") as a HASH ref while "strict refs" in use at
> > /usr/local/lib/perl5/site_perl/5.8.1/sun4-solaris/DBI.pm line 509
> > 
> > What can be the problem?
> 
> Looking at line 509 of your DBI.pm might give you a clue.
> Enabling the DBI trace mechanism is another way to get a clue.
> If neither help you then post them here so they can help us help you.
> Posting your code that calls connect() may also help.
> 
> Tim.


