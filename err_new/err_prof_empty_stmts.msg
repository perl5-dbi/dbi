From timbo@dansat.data-plan.com  Fri Jan 23 14:06:25 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i0NE67kk000681
	for <timbo@localhost>; Fri, 23 Jan 2004 14:06:25 GMT
	(envelope-from timbo@dansat.data-plan.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 23 Jan 2004 14:06:25 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1Ajxll-0001Pa-Dm;
	Fri, 23 Jan 2004 09:38:31 +0000
Received: from [208.58.1.193] (helo=boggle.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1Ajxll-0001Pa-Dm
	for pobox@dbi.demon.co.uk; Fri, 23 Jan 2004 09:38:29 +0000
Received: from boggle.pobox.com (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 978261C3A9
	for <pobox@dbi.demon.co.uk>; Fri, 23 Jan 2004 04:38:28 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 4AD831C380
	for <Tim.Bunce@pobox.com>; Fri, 23 Jan 2004 04:38:28 -0500 (EST)
Received: from mail09.svc.cra.dublin.eircom.net (mail09.svc.cra.dublin.eircom.net [159.134.118.25])
	by boggle.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Fri, 23 Jan 2004 04:38:27 -0500 (EST)
Received: (qmail 12160 messnum 308917 invoked from network[213.94.228.233/unknown]); 23 Jan 2004 09:38:25 -0000
Received: from unknown (HELO dansat.data-plan.com) (213.94.228.233)
  by mail09.svc.cra.dublin.eircom.net (qp 12160) with SMTP; 23 Jan 2004 09:38:25 -0000
Received: from dansat.data-plan.com (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i0N9f0FO018788;
	Fri, 23 Jan 2004 09:41:00 GMT
	(envelope-from timbo@dansat.data-plan.com)
Received: (from timbo@localhost)
	by dansat.data-plan.com (8.12.9/8.12.9/Submit) id i0N9ex9G018787;
	Fri, 23 Jan 2004 09:40:59 GMT
Date: Fri, 23 Jan 2004 09:40:59 +0000
From: Tim Bunce <Tim.Bunce@pobox.com>
To: Ask =?iso-8859-1?Q?Bj=F8rn?= Hansen <ask@develooper.com>
Cc: Tim Bunce <Tim.Bunce@pobox.com>
Subject: Re: odd DBI::Profile output
Message-ID: <20040123094059.GB18607@dansat.data-plan.com>
References: <A948AA82-4D5A-11D8-9AC7-000A95796C18@develooper.com>
Mime-Version: 1.0
Content-Type: text/plain; charset=iso-8859-1
Content-Disposition: inline
In-Reply-To: <A948AA82-4D5A-11D8-9AC7-000A95796C18@develooper.com>
User-Agent: Mutt/1.4i
Content-Transfer-Encoding: 8bit
X-MIME-Autoconverted: from quoted-printable to 8bit by dansat.data-plan.com id i0NE67kk000681
Status: RO
Content-Length: 1240
Lines: 46

On Thu, Jan 22, 2004 at 08:14:38PM -0800, Ask Bjørn Hansen wrote:
> 
> Only just started using DBI::Profile; it's awesome!

Yeah. Thanks.

> I get a lot of 
> empty statements in my output files; for example the one below.  Could 
> that be $dbh->ping() or is it truly an empty statement?!  I tried 
> enabling tracing too, but it didn't help me.

It'll be $dbh methods, like ping, that aren't associated with "the
last statement".

It would probably be more helpful if it used the method name in those
cases. Try changing the two lines that look like

  char *Statement = (ima && ima->flags & IMA_PROF_EMPTY_STMT) ? "" : Nullch;

to
  char *Statement = (ima && ima->flags & IMA_PROF_EMPTY_STMT) ? meth_name : Nullch;

and let me know how well that works for you.

You may still get some empty statements, bt that's another story.

Tim.


>  - ask
> 
> #####[ 1 ]###########################################################
>   Count         : 122
>   Total Time    : 1.799721 seconds
>   Longest Time  : 0.189048 seconds
>   Shortest Time : 0.000002 seconds
>   Average Time  : 0.014752 seconds
>   Key 1         :
> 
> #####[ 2 ]###########################################################
> 
> 
> -- 
> http://www.askbjoernhansen.com/
> 


