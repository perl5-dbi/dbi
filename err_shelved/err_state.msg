From timbo@dansat.data-plan.com  Tue Sep 30 21:52:31 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id h8UKqFCF048073
	for <timbo@localhost>; Tue, 30 Sep 2003 21:52:30 +0100 (BST)
	(envelope-from timbo@dansat.data-plan.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Tue, 30 Sep 2003 21:52:30 +0100 (BST)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1A4R9E-0004hS-Aq;
	Tue, 30 Sep 2003 20:31:04 +0000
Received: from [207.106.49.21] (helo=wink.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1A4R9E-0004hS-Aq
	for pobox@dbi.demon.co.uk; Tue, 30 Sep 2003 20:31:04 +0000
Received: from wink.pobox.com (localhost[127.0.0.1])
	by wink.pobox.com (Postfix) with ESMTP id D6C691EA6D
	for <pobox@dbi.demon.co.uk>; Tue, 30 Sep 2003 16:31:03 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from mail03.svc.cra.dublin.eircom.net (mail03.svc.cra.dublin.eircom.net[159.134.118.19])
	by wink.pobox.com (Postfix) with SMTP id 201C116A7C
	for <Tim.Bunce@pobox.com>; Tue, 30 Sep 2003 16:31:03 -0400 (EDT)
Received: (qmail 61234 messnum 176167 invoked from network[213.94.228.233/unknown]); 30 Sep 2003 20:31:01 -0000
Received: from unknown (HELO dansat.data-plan.com) (213.94.228.233)
  by mail03.svc.cra.dublin.eircom.net (qp 61234) with SMTP; 30 Sep 2003 20:31:01 -0000
Received: from dansat.data-plan.com (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id h8UKV9C3047848;
	Tue, 30 Sep 2003 21:31:09 +0100 (BST)
	(envelope-from timbo@dansat.data-plan.com)
Received: (from timbo@localhost)
	by dansat.data-plan.com (8.12.9/8.12.9/Submit) id h8UKV8Ic047847;
	Tue, 30 Sep 2003 21:31:08 +0100 (BST)
Date: Tue, 30 Sep 2003 21:31:08 +0100
From: Tim Bunce <Tim.Bunce@pobox.com>
To: Ronald J Kimball <rjk-dbi@focalex.com>
Cc: Tim Bunce <Tim.Bunce@pobox.com>, Hardy Merrill <hmerrill@redhat.com>,
   Andy Hassall <andy@andyh.co.uk>, dbi-users@perl.org
Subject: Re: Insert return value
Message-ID: <20030930203108.GQ42989@dansat.data-plan.com>
References: <20030929155836.GH88918@dansat.data-plan.com> <20030929161417.GA24725@merrill.boston.redhat.com> <20030929194317.GO88918@dansat.data-plan.com> <20030929200232.GA25453@merrill.boston.redhat.com> <20030929203645.GA25651@merrill.boston.redhat.com> <011601c386cf$6a1c2ed0$0e64a8c0@excession> <20030929223529.GB88918@dansat.data-plan.com> <20030930125735.GA27929@merrill.boston.redhat.com> <20030930172427.GI42989@dansat.data-plan.com> <20030930133157.G25344@rkimball.focalex.com>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <20030930133157.G25344@rkimball.focalex.com>
User-Agent: Mutt/1.4i
Status: RO
Content-Length: 1253
Lines: 27

On Tue, Sep 30, 2003 at 01:31:57PM -0400, Ronald J Kimball wrote:
> On Tue, Sep 30, 2003 at 06:24:27PM +0100, Tim Bunce wrote:
> > On Tue, Sep 30, 2003 at 08:57:35AM -0400, Hardy Merrill wrote:
> > > 
> > > My thought was that we'd
> > > somehow want to know specifically that the violation is caused
> > > by an attempt to insert a duplicate key, but 23000 is a
> > > "generic" constraint violation error.  Is a generic constraint
> > > violation error what we want for this?
> > 
> > It's all the standard gives you.
> > 
> > If you need more details there's always $h->errstr ...
> 
> I like the idea of having standard error values to check for, but if we
> have to fall back to $dbh->errstr() anyway, I'm not sure what we're gaining
> from this.  Personally, I've written a lot of code that checks for unique
> constraint violations.  Detecting a generic constraint violation, without
> knowing what type of constraint was violated, just doesn't seem very
> useful to me.

I think a lot of people/applications would be happy to have a
standard way to check for a constraint violation; knowing that in
their lives, and their databases e.g., mysql with MyISAM tables,
the only constraint violation on an insert would be due to a duplicate key.

Tim.

