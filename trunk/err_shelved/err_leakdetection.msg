From dbi-users-return-9689-Tim.Bunce=pobox.com@perl.org  Thu Feb 28 07:32:41 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g1S7WfU36991
	for <timbo@localhost>; Thu, 28 Feb 2002 07:32:41 GMT
	(envelope-from dbi-users-return-9689-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.21]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Thu, 28 Feb 2002 07:32:41 +0000 (GMT)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1014854095:10:17290:13; Wed, 27 Feb 2002 23:54:55 GMT
Received: from wormwood.pobox.com ([208.210.125.20]) by punt-1.mail.demon.net
           id aa1017213; 27 Feb 2002 23:54 GMT
Received: from wormwood.pobox.com (localhost.pobox.com [127.0.0.1])
	by wormwood.pobox.com (Postfix) with ESMTP id D22B772568
	for <Tim.Bunce@data-plan.com>; Wed, 27 Feb 2002 18:54:48 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [209.85.157.220])
	by wormwood.pobox.com (Postfix) with SMTP id 039EA72555
	for <Tim.Bunce@pobox.com>; Wed, 27 Feb 2002 18:54:46 -0500 (EST)
Received: (qmail 10819 invoked by uid 1005); 27 Feb 2002 23:54:45 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 10803 invoked by uid 76); 27 Feb 2002 23:54:44 -0000
Received: from stephenc.theiqgroup.com (HELO stephenc.theiqgroup.com) (216.81.249.18)
  by onion.perl.org (qpsmtpd/0.06) with SMTP; Wed Feb 27 23:54:44 2002 -0000
Received: (from stephenc@localhost)
	by stephenc.theiqgroup.com (8.11.1/8.11.1) id g1RNsZe04191;
	Wed, 27 Feb 2002 17:54:35 -0600
Date: Wed, 27 Feb 2002 17:54:35 -0600
From: Stephen Clouse <stephenc@theiqgroup.com>
To: Ken Miller <klm@shetlandsoftware.com>
Cc: dbi-users@perl.org
Subject: Re: Leaking SV's with DBI - how to find where?
Message-ID: <20020227235435.GB2921@owns.warpcore.org>
Mail-Followup-To: Ken Miller <klm@shetlandsoftware.com>,
	dbi-users@perl.org
References: <017f01c1bfdb$08b383d0$ff430a9b@HuskyEnergy.Ca>
Mime-Version: 1.0
Content-Type: text/plain
Content-Disposition: inline; filename="msg.pgp"
In-Reply-To: <017f01c1bfdb$08b383d0$ff430a9b@HuskyEnergy.Ca>
User-Agent: Mutt/1.3.25i
Status: RO
Content-Length: 1161
Lines: 31

-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA1

On Wed, Feb 27, 2002 at 03:06:40PM -0700, Ken Miller wrote:
> Is there a way to track down where the leaks are occurring without placing
> debugging messages everywhere?  77 SVs isn't a lot, but when this many SVs
> are leaked per iteration, and you've got about a million rows to rip
> through, it adds up to a *lot*.

I find Devel::Leak to be very useful in this regard, as it will actually do a 
Perl_sv_dump() on the orphaned SVs.  From there you can generally track down 
where it's coming from, particularly if you put a signal flare in the structure 
you think is escaping deallocation, say:

	$struct->{foo} = 'YOU HAVE A LEAK';

When the string reemerges in the Devel::Leak output, the problem becomes pretty 
apparent :)

- -- 
Stephen Clouse <stephenc@theiqgroup.com>
Senior Programmer, IQ Coordinator Project Lead
The IQ Group, Inc. <http://www.theiqgroup.com/>
-----BEGIN PGP SIGNATURE-----
Version: GnuPG v1.0.6 (GNU/Linux)
Comment: For info see http://www.gnupg.org

iEYEARECAAYFAjx9cbsACgkQA4aoazQ9p2d0wwCgh5yv4I6RTEwYW8jgmaDm2UWC
MdEAoN+gadssDYLxZQuVbtTUgjW4kvVK
=DxRC
-----END PGP SIGNATURE-----

