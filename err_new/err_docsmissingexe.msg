From nobody@fsck.com  Wed Dec  3 18:35:24 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id hB3IXdo4059766
	for <timbo@localhost>; Wed, 3 Dec 2003 18:35:24 GMT
	(envelope-from nobody@fsck.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Wed, 03 Dec 2003 18:35:24 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1ARVYC-0004Sc-8f;
	Wed, 03 Dec 2003 11:52:51 +0000
Received: from [208.58.1.193] (helo=boggle.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1ARVYC-0004Sc-8f
	for pobox@dbi.demon.co.uk; Wed, 03 Dec 2003 11:52:12 +0000
Received: from boggle.pobox.com (localhost[127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 67AF42F4793
	for <pobox@dbi.demon.co.uk>; Wed,  3 Dec 2003 06:52:11 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost[127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 2B3092F4719
	for <Tim.Bunce@pobox.com>; Wed,  3 Dec 2003 06:52:11 -0500 (EST)
Received: from ran-out.mx.develooper.com (one.develooper.com[64.81.84.115])
	by boggle.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Wed,  3 Dec 2003 06:52:09 -0500 (EST)
Received: (qmail 4197 invoked by uid 225); 3 Dec 2003 11:52:08 -0000
Delivered-To: TIMB@cpan.org
Received: (qmail 4182 invoked by uid 507); 3 Dec 2003 11:51:59 -0000
Received: from pallas.eruditorum.org (HELO pallas.eruditorum.org) (63.251.136.85) by one.develooper.com (qpsmtpd/0.27-dev) with ESMTP; Wed, 03 Dec 2003 03:51:28 -0800
Received: by pallas.eruditorum.org (Postfix, from userid 65534)	id C70F61138E; Wed,  3 Dec 2003 06:51:24 -0500 (EST)
Subject: [cpan #4555] Missing execute in docs 
From: "Iain Truskett via RT" <bug-DBI@rt.cpan.org>
Reply-To: bug-DBI@rt.cpan.org
In-Reply-To: <rt-4555@cpan>
Message-ID: <rt-4555-13485.14.9796953036239@cpan.org>
Precedence: bulk
X-RT-Loop-Prevention: cpan
RT-Ticket: cpan #4555
Managed-by: RT 2.0.15 (http://bestpractical.com/rt/)
RT-Originator: SPOON@cpan.org
To: "AdminCc of cpan Ticket #4555": ;
Date: Wed,  3 Dec 2003 06:51:24 -0500 (EST)
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=2.1 required=7.0 tests=CARRIAGE_RETURNS,IN_REP_TO,SPAM_PHRASE_01_02,TO_HAS_SPACES,TO_MALFORMED version=2.44
Status: RO
X-Status: A
Content-Length: 537
Lines: 20


This message about DBI was sent to you by SPOON <SPOON@cpan.org> via rt.cpan.org

Full context and any attached attachments can be found at:
<URL: https://rt.cpan.org/Ticket/Display.html?id=4555 >

In fetchall_hashref:

  $dbh->{FetchHashKeyName} = 'NAME_lc';
  $sth = $dbh->prepare("SELECT FOO, BAR, ID, NAME, BAZ FROM TABLE");
  $hash_ref = $sth->fetchall_hashref('id');
  print "Name for id 42 is $hash_ref->{42}->{name}\n";

That should have an << $sth->execute; >> between the prepare and
the fetchall_hashref.


cheers,
-- 
Iain.

