From dbi-users-return-9708-Tim.Bunce=pobox.com@perl.org  Thu Feb 28 15:13:20 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g1SFDKU40298
	for <timbo@localhost>; Thu, 28 Feb 2002 15:13:20 GMT
	(envelope-from dbi-users-return-9708-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.58]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Thu, 28 Feb 2002 15:13:20 +0000 (GMT)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1014908847:20:07471:26; Thu, 28 Feb 2002 15:07:27 GMT
Received: from cali-3.pobox.com ([64.71.166.116]) by punt-2.mail.demon.net
           id aa2112148; 28 Feb 2002 15:07 GMT
Received: from cali-3.pobox.com (localhost.localdomain [127.0.0.1])
	by cali-3.pobox.com (Postfix) with ESMTP id 3E0CB3E6B4
	for <Tim.Bunce@data-plan.com>; Thu, 28 Feb 2002 10:00:41 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [209.85.157.220])
	by cali-3.pobox.com (Postfix) with SMTP id 18F453E6B2
	for <Tim.Bunce@pobox.com>; Thu, 28 Feb 2002 10:00:41 -0500 (EST)
Received: (qmail 39714 invoked by uid 1005); 28 Feb 2002 15:00:31 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 39648 invoked by uid 76); 28 Feb 2002 15:00:16 -0000
Received: from 66-3-212-3.customer.algx.net (HELO mail.focalex.com) (66.3.212.3)
  by onion.perl.org (qpsmtpd/0.06) with SMTP; Thu Feb 28 15:00:16 2002 -0000
Received: (from rjk@localhost)
	by mail.focalex.com (8.9.3/8.9.3) id JAA25121;
	Thu, 28 Feb 2002 09:56:15 -0500
Date: Thu, 28 Feb 2002 09:56:15 -0500
From: Ronald J Kimball <rjk-dbi@focalex.com>
To: Tim Bunce <Tim.Bunce@pobox.com>
Cc: dbi-users <dbi-users@perl.org>
Subject: Re: [PATCH] Optionally prevent prepare_cached from calling finish on active handle
Message-ID: <20020228095615.I5083@herschel.focalex.com>
References: <20020228043816.GG2921@owns.warpcore.org> <20020228085505.G5083@herschel.focalex.com> <20020228141124.T17360@dansat.data-plan.com>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
X-Mailer: Mutt 1.0.1i
In-Reply-To: <20020228141124.T17360@dansat.data-plan.com>; from Tim.Bunce@pobox.com on Thu, Feb 28, 2002 at 02:11:24PM +0000
Status: RO
X-Status: A
Content-Length: 453
Lines: 19

On Thu, Feb 28, 2002 at 02:11:24PM +0000, Tim Bunce wrote:
> On Thu, Feb 28, 2002 at 08:55:05AM -0500, Ronald J Kimball wrote:
> > That should be written as either:
> > 
> > C<$sth-E<gt>{Active}>
> > 
> > or:
> > 
> > C<< $sth->{Active} >>
> 
> What's the oldest version of perl that supports those forms of pod
> for all pod translators?

C<$sth-E<gt>{Active}> should work fine in 5.004, possibly earlier.

C<< $sth->{Active} >> requires 5.6.

Ronald


