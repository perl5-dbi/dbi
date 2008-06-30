From aclarke@t-mobile.co.uk  Fri May  9 10:51:53 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.6/8.12.6) with ESMTP id h499nm3R096740
	for <timbo@localhost>; Fri, 9 May 2003 10:51:53 +0100 (BST)
	(envelope-from aclarke@t-mobile.co.uk)
Received: from pop3.mail.demon.net [194.217.242.23]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 09 May 2003 10:51:53 +0100 (BST)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1052468994:20:27880:8; Fri, 09 May 2003 08:29:54 GMT
Received: from orb.pobox.com ([208.210.125.79]) by punt-2.mail.demon.net
           id aa2027183; 9 May 2003 8:29 GMT
Received: from orb.pobox.com (localhost [127.0.0.1])
	by orb.pobox.com (Postfix) with ESMTP id F270D1560AD
	for <Tim.Bunce@data-plan.com>; Fri,  9 May 2003 04:25:56 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from one2one.t-mobile.co.uk (one2one.t-mobile.co.uk [149.254.120.220])
	by orb.pobox.com (Postfix) with ESMTP id 7CA06155FDD
	for <Tim.Bunce@pobox.com>; Fri,  9 May 2003 04:25:56 -0400 (EDT)
Received: from belize.t-mobile.co.uk (belize [172.24.18.238])
	by one2one.t-mobile.co.uk (8.12.9/8.12.9) with ESMTP id h498PsKY026659
	for <Tim.Bunce@pobox.com>; Fri, 9 May 2003 09:25:54 +0100 (BST)
Received: from bolivia.t-mobile.co.uk (localhost [127.0.0.1])
	by belize.t-mobile.co.uk (8.12.9/8.12.9) with ESMTP id h498PsJW002801
	for <Tim.Bunce@pobox.com>; Fri, 9 May 2003 09:25:54 +0100 (BST)
Received: from vino.t-mobile.co.uk (vino [172.23.62.229])
	by bolivia.t-mobile.co.uk (8.12.9/8.12.9) with ESMTP id h498PrlD023156
	for <Tim.Bunce@pobox.com>; Fri, 9 May 2003 09:25:53 +0100 (BST)
Received: from vino (vino [172.23.62.229])
	by vino.t-mobile.co.uk (8.12.9/8.12.9) with SMTP id h498Pr0l013910
	for <Tim.Bunce@pobox.com>; Fri, 9 May 2003 09:25:53 +0100 (BST)
Message-Id: <200305090825.h498Pr0l013910@vino.t-mobile.co.uk>
Date: Fri, 9 May 2003 09:25:53 +0100 (BST)
From: Anthony Clarke <aclarke@t-mobile.co.uk>
Reply-To: Anthony Clarke <aclarke@t-mobile.co.uk>
Subject: Re: Do you use DBD::Multiplex ?
To: Tim.Bunce@pobox.com
MIME-Version: 1.0
Content-Type: TEXT/plain; charset=ISO-8859-15
Content-MD5: EPDzqrKz/w9fFL1V+Op+8g==
X-Mailer: dtmail 1.3.0 @(#)CDE Version 1.4.6_06 SunOS 5.8 sun4u sparc 
Content-Transfer-Encoding: 8bit
X-MIME-Autoconverted: from QUOTED-PRINTABLE to 8bit by dansat.data-plan.com id h499nm3R096740
Status: RO
X-Status: A
Content-Length: 1841
Lines: 61

Tim,

I have been thinking about how I might use this and an issue which I have come 
across is the fact that the various databases I have use different 
username/password combinations. In particular, I am using Oracle where I have to 
specify username/password and DB2 UDB where authentication is by OS user and no 
password is required.

If we could specify a list as with the DSNs it would help.

Regards,

Anthony

>Mailing-List: contact dbi-announce-help@perl.org; run by ezmlm
>List-Post: <mailto:dbi-announce@perl.org>
>List-Help: <mailto:dbi-announce-help@perl.org>
>List-Unsubscribe: <mailto:dbi-announce-unsubscribe@perl.org>
>List-Subscribe: <mailto:dbi-announce-subscribe@perl.org>
>Delivered-To: mailing list dbi-announce@perl.org
>Delivered-To: moderator for dbi-announce@perl.org
>Delivered-To: dbi-announce@perl.org
>Date: Tue, 6 May 2003 13:27:13 +0100
>From: Tim Bunce <Tim.Bunce@pobox.com>
>To: dbi-announce@perl.org
>Cc: dbi-users@perl.org
>Subject: Do you use DBD::Multiplex ?
>Mime-Version: 1.0
>Content-Disposition: inline
>User-Agent: Mutt/1.4i
>X-SMTPD: qpsmtpd/0.26-dev, http://develooper.com/code/qpsmtpd/
>X-Spam-Check-By: one.develooper.com
>X-Spam-Status: No, hits=-0.6 required=7.0 
tests=CARRIAGE_RETURNS,SPAM_PHRASE_02_03,USER_AGENT,USER_AGENT_MUTT version=2.44
>X-SMTPD: qpsmtpd/0.26-dev, http://develooper.com/code/qpsmtpd/
>X-Keywords: 
>
>I'm currently working on some major changes to DBD::Multiplex.
>
>I'd like to hear from anyone using it in a production environment,
>with details of how you're using it and what you'd like to see changed.
>
>Thanks.
>
>Tim.

Regards / Mit freundlichen Grüßen

Anthony

__________________________________________________

Anthony Clarke
Open Systems Group
T-Systems Ltd
Imperial Place, Borehamwood, Herts WD6 1EA
Tel: +44-(0)20-8214-2944
Fax: +44-(0)7957-468413




