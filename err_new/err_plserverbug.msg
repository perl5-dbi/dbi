From cdbi-talk-owner@groups.kasei.com  Wed Jun 25 17:35:50 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id h5PGVt3q014863
	for <timbo@localhost>; Wed, 25 Jun 2003 17:35:50 +0100 (BST)
	(envelope-from cdbi-talk-owner@groups.kasei.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Wed, 25 Jun 2003 17:35:50 +0100 (BST)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1056534336:20:02020:23; Wed, 25 Jun 2003 09:45:36 GMT
Received: from icicle-214-2.pobox.com ([207.8.214.2]) by punt-2.mail.demon.net
           id aa2123416; 25 Jun 2003 9:44 GMT
Received: from icicle.pobox.com (localhost [127.0.0.1])
	by icicle.pobox.com (Postfix) with ESMTP id E35FD5813E
	for <Tim.Bunce@data-plan.com>; Wed, 25 Jun 2003 05:44:06 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from soto.kasei.com (soto.kasei.com [80.76.206.154])
	by icicle.pobox.com (Postfix) with ESMTP
	id 77BA4580EC; Wed, 25 Jun 2003 05:44:06 -0400 (EDT)
Received: by soto.kasei.com (Postfix, from userid 103)
	id 912551C35B; Wed, 25 Jun 2003 10:44:02 +0100 (BST)
X-Original-To: cdbi-talk@groups.kasei.com
Delivered-To: group-post+cdbi-talk@soto.kasei.com
Received: by soto.kasei.com (Postfix, from userid 1011)
	id E063E1C331; Wed, 25 Jun 2003 10:43:58 +0100 (BST)
Date: Wed, 25 Jun 2003 10:43:58 +0100
From: Tony Bowden <tony@kasei.com>
To: cdbi-talk@groups.kasei.com
Subject: Re: Preventing stringification
Message-ID: <20030625094358.GA10666@soto.kasei.com>
Mail-Followup-To: cdbi-talk@groups.kasei.com
References: <sympa.1056482661.13197.617@groups.kasei.com>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <sympa.1056482661.13197.617@groups.kasei.com>
User-Agent: Mutt/1.5.4i
X-Loop: cdbi-talk@groups.kasei.com
X-Sequence: 1203
Precedence: list
X-no-archive: yes
List-Id: <cdbi-talk@groups.kasei.com>
List-Help: <mailto:sympa@groups.kasei.com?subject=help>
List-Subscribe: <mailto:sympa@groups.kasei.com?subject=subscribe%20cdbi-talk>
List-Unsubscribe: <mailto:sympa@groups.kasei.com?subject=unsubscribe%20cdbi-talk>
List-Post: <mailto:cdbi-talk@groups.kasei.com>
List-Owner: <mailto:cdbi-talk-request@groups.kasei.com>
List-Archive: <http://groups.kasei.com/mail/arc/cdbi-talk>
Status: RO
Content-Length: 580
Lines: 13

On Tue, Jun 24, 2003 at 10:04:10PM +0100, johannes_niess@web.de wrote:
> RPC::PlServer uses Storable.pm to serialize ("nfreeze()") and transport
> the object to the remote client. "thaw()"'ing on the client does not return
> an object because of stringification. RPC::PlServer checks for object ref's via 
> '::' which stringified DB id's ('1') don't match.

Smells like a bug in RPC::PlServer to me. Even if $obj overloads to 1,
ref $obj will still be the Class::Name.

Aside from that, checking for :: is dangerous anyway, as classes could be
in a top level namespace ...

Tony

