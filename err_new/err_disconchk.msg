From dbi-users-return-21640-Tim.Bunce=pobox.com@perl.org  Sat Jan 17 15:09:20 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i0HF9IFQ054889
	for <timbo@localhost>; Sat, 17 Jan 2004 15:09:20 GMT
	(envelope-from dbi-users-return-21640-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Sat, 17 Jan 2004 15:09:20 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1Ahr9i-0003JP-Me;
	Sat, 17 Jan 2004 14:10:30 +0000
Received: from [208.210.124.70] (helo=majesty.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1Ahr9i-0003JP-Me
	for pobox@dbi.demon.co.uk; Sat, 17 Jan 2004 14:10:30 +0000
Received: from majesty.pobox.com (localhost [127.0.0.1])
	by majesty.pobox.com (Postfix) with ESMTP id D76E112917
	for <pobox@dbi.demon.co.uk>; Sat, 17 Jan 2004 09:10:28 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by majesty.pobox.com (Postfix) with ESMTP id 2E679128F4
	for <Tim.Bunce@pobox.com>; Sat, 17 Jan 2004 09:10:27 -0500 (EST)
Received: from onion.perl.org (onion.develooper.com [63.251.223.166])
	by majesty.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Sat, 17 Jan 2004 09:10:19 -0500 (EST)
Received: (qmail 57807 invoked by uid 1005); 17 Jan 2004 14:10:08 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 57790 invoked by uid 76); 17 Jan 2004 14:10:08 -0000
Received: from qmailr@one.develooper.com (HELO ran-out.mx.develooper.com) (64.81.84.115) by onion.perl.org (qpsmtpd/0.26) with SMTP; Sat, 17 Jan 2004 06:10:08 -0800
Received: (qmail 4993 invoked by uid 225); 17 Jan 2004 14:10:01 -0000
Delivered-To: dbi-users@perl.org
Received: (qmail 4987 invoked by uid 507); 17 Jan 2004 14:10:00 -0000
Received: from mail07.svc.cra.dublin.eircom.net (HELO mail07.svc.cra.dublin.eircom.net) (159.134.118.23) by one.develooper.com (qpsmtpd/0.27-dev) with SMTP; Sat, 17 Jan 2004 06:09:29 -0800
Received: (qmail 6037 messnum 914551 invoked from network[213.94.228.233/unknown]); 17 Jan 2004 14:09:25 -0000
Received: from unknown (HELO dansat.data-plan.com) (213.94.228.233)  by mail07.svc.cra.dublin.eircom.net (qp 6037) with SMTP; 17 Jan 2004 14:09:25 -0000
Received: from dansat.data-plan.com (localhost [127.0.0.1])	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i0HEApFO054421;	Sat, 17 Jan 2004 14:10:51 GMT	(envelope-from timbo@dansat.data-plan.com)
Received: (from timbo@localhost)	by dansat.data-plan.com (8.12.9/8.12.9/Submit) id i0HEAn3s054420;	Sat, 17 Jan 2004 14:10:49 GMT
Date: Sat, 17 Jan 2004 14:10:49 +0000
From: Tim Bunce <Tim.Bunce@pobox.com>
To: Jonathan Leffler <jleffler@us.ibm.com>
Cc: Tim Bunce <Tim.Bunce@pobox.com>,
   DBI Users Mailing List <dbi-users@perl.org>,
   Jonathan Leffler <jleffler@earthlink.net>
Subject: Re: DBI: Why don't statement handles fail after $dbh->disconnect?
Message-ID: <20040117141049.GA54251@dansat.data-plan.com>
References: <20040116220814.GC43478@dansat.data-plan.com> <OF45F87E08.DED87A93-ON87256E1D.007D3EFD-88256E1D.007F88FD@us.ibm.com>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <OF45F87E08.DED87A93-ON87256E1D.007D3EFD-88256E1D.007F88FD@us.ibm.com>
User-Agent: Mutt/1.4i
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=-2.6 required=7.0 tests=CARRIAGE_RETURNS,DEAR_SOMEBODY,IN_REP_TO,QUOTED_EMAIL_TEXT,REFERENCES,SPAM_PHRASE_00_01,USER_AGENT,USER_AGENT_MUTT version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Status: RO
Content-Length: 3291
Lines: 78

On Fri, Jan 16, 2004 at 03:14:18PM -0800, Jonathan Leffler wrote:
>    Sorry about a top-posted response - Lotus is what it is.
> 
>    So, the DBI code does not track the statement handles associated with a database handle,

Does not now. Will later (using weak refs).

>    and does not invalidate them when the connection is disconnected?

No.

>    DBD::Informix has code that invalidates the statement handles when the $dbh itself is destroyed, but
>    that happens separately from and after the connection is broken.
>    So, I guess I need to check whether the connection is still valid. OK...(but it is common logic for all
>    drivers - shouldn't DBI handle it for the drivers? In v2 perhaps?)

It does in some places. For example the Driver.xst code for finish()
checks that the parent dbh of the sth is still active. I could
extend that to some more methods.

Tim.

>    --
>    Jonathan Leffler (jleffler@us.ibm.com)
>    STSM, Informix Database Engineering, IBM Data Management
>    4100 Bohannon Drive, Menlo Park, CA 94025
>    Tel: +1 650-926-6921 Tie-Line: 630-6921
>    "I don't suffer from insanity; I enjoy every minute of it!"
> 
>    Inactive hide details for Tim Bunce <Tim.Bunce@pobox.com>Tim Bunce <Tim.Bunce@pobox.com>
> 
>                Tim Bunce             To: Jonathan Leffler/Menlo Park/IBM@IBMUS                              
>                <Tim.Bunce@pobox.com> cc: DBI Users Mailing List <dbi-users@perl.org>, Jonathan Leffler      
>                                      <jleffler@earthlink.net>                                               
>                01/16/2004 02:08 PM   Subject: Re: DBI: Why don't statement handles fail after               
>                                      $dbh->disconnect?                                                      
> 
>    On Fri, Jan 16, 2004 at 12:21:38PM -0800, Jonathan Leffler wrote:
>    > Dear Tim,
>    >
>    > Consider the following test code - using the NullP driver.
>    >
>    >     #!/bin/perl -w
>    >     #
>    >     # Test that statement handles from disconnected connections fail!
>    >     use strict;
>    >     use DBI;
>    >     my $table = "dbd_tester";
>    >     my $dbh = DBI->connect('dbi:NullP:immaterial', '', '', {RaiseError=>1});
>    >     my $sth = $dbh->prepare(qq{INSERT INTO $table VALUES(?)});
>    >     $dbh->disconnect;
>    >     $sth->execute(1);
>    >     print "** Failed to FAIL!\n";
>    >
>    > With both as written and with DBD::Informix replacing the NullP driver,
>    > the code reaches that print statement, when it shouldn't, I think,
>    > because $dbh->disconnect should have invalidated $sth.
>    >
>    > Is this a bug - or a feature?  And where is it a bug or feature?  DBI,
>    > or in the drivers?
> 
>    It's certainly an issue in the drivers. Bug or feature is harder to say.
> 
>    Many would reasonably take the view that the underlying database
>    calls would fail if the database had been disconnected. If it
>    doesn't, well good luck to you. The disconnect should disconnect
>    and so long as it's done that then it worked. There's no guarantee
>    that the handle won't be usable.
> 
>    The docs say "The handle is of little use after disconnecting."
> 
>    Perhaps I should add "probably" :)
> 
>    Tim.





