From dbi-users-return-8368-Tim.Bunce=pobox.com@perl.org  Mon Jan  7 12:41:55 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g07CftU22020
	for <timbo@localhost>; Mon, 7 Jan 2002 12:41:55 GMT
	(envelope-from dbi-users-return-8368-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.22]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Mon, 07 Jan 2002 12:41:55 +0000 (GMT)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1010405559:10:17922:31; Mon, 07 Jan 2002 12:12:39 GMT
Received: from wormwood.pobox.com ([208.210.125.20]) by punt-1.mail.demon.net
           id aa1126847; 7 Jan 2002 12:12 GMT
Received: from wormwood.pobox.com (localhost.pobox.com [127.0.0.1])
	by wormwood.pobox.com (Postfix) with ESMTP id 5870C72517
	for <Tim.Bunce@data-plan.com>; Mon,  7 Jan 2002 07:12:13 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [209.85.157.220])
	by wormwood.pobox.com (Postfix) with SMTP id 48FD3725AC
	for <Tim.Bunce@pobox.com>; Mon,  7 Jan 2002 07:12:12 -0500 (EST)
Received: (qmail 78049 invoked by uid 1005); 7 Jan 2002 12:12:05 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Delivered-To: moderator for dbi-users@perl.org
Received: (qmail 74601 invoked by uid 76); 7 Jan 2002 11:55:17 -0000
Date: Mon, 7 Jan 2002 11:55:03 +0000
From: Graham Barr <gbarr@pobox.com>
To: Tim Bunce <Tim.Bunce@pobox.com>
Cc: "Randal L. Schwartz" <merlyn@stonehenge.com>, dbi-users@perl.org
Subject: Re: Subclassing - draft docs (Re: Important: Subclassing and Merg	ing DBIx::AnyDBD into the DBI)
Message-ID: <20020107115503.M14235@pobox.com>
References: <B1FA93A1B9A9D31189EC00508B6140CD065A0E59@KPEXS08> <3C35DFC3.6090607@globalsports.com> <20020105012243.D75939@dansat.data-plan.com> <m1zo3sbyr4.fsf@halfdome.holdit.com> <20020106224336.M75939@dansat.data-plan.com>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
User-Agent: Mutt/1.2.5i
In-Reply-To: <20020106224336.M75939@dansat.data-plan.com>; from Tim.Bunce@pobox.com on Sun, Jan 06, 2002 at 10:43:36PM +0000
Status: RO
X-Status: A
Content-Length: 930
Lines: 24

On Sun, Jan 06, 2002 at 10:43:36PM +0000, Tim Bunce wrote:
> > If people want per-DBI-handle data, why not provide the data via
> > $dbh->private instead, which returns a hashref unique to the handle?
> 
> And shared by all other classes/code which wants to use per-handle data.
> Doesn't seem to be much of a win.
> 
> Though it crosses my mind that a $h->private(__PACKAGE__, 'foo') interface
> would at least force people to consider namespace polution/protection.

This is similar to what we did in Tk a long time ago. There is a method
->private which takes an optional package name, if the package is
not given it defaults to the callers package. It simply returns a hashref
for the caller to use. It was meant for subclasses to store thier own data
without clashing. The code for Tk was something like

sub private {
  my $self = shift;
  my $pkg = shift || caller;
  return $self->{private_data}{$pkg} ||= {};
}

Graham.


