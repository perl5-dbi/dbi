From cdbi-talk-owner@groups.kasei.com  Thu Aug  7 15:16:23 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id h77EFs5s048536
	for <timbo@localhost>; Thu, 7 Aug 2003 15:16:22 +0100 (BST)
	(envelope-from cdbi-talk-owner@groups.kasei.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Thu, 07 Aug 2003 15:16:22 +0100 (BST)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 19kjFB-0002rO-Dj;
	Thu, 07 Aug 2003 11:47:45 +0000
Received: from [216.65.124.72] (helo=orb.pobox.com)
	by punt-3.mail.demon.net with esmtp id 19kjFB-0002rO-Dj
	for pobox@dbi.demon.co.uk; Thu, 07 Aug 2003 11:47:45 +0000
Received: from orb.pobox.com (localhost [127.0.0.1])
	by orb.pobox.com (Postfix) with ESMTP id A166815633B
	for <pobox@dbi.demon.co.uk>; Thu,  7 Aug 2003 07:47:44 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from soto.kasei.com (soto.kasei.com [80.76.206.154])
	by orb.pobox.com (Postfix) with ESMTP
	id 1A1D915619D; Thu,  7 Aug 2003 07:47:44 -0400 (EDT)
Received: by soto.kasei.com (Postfix, from userid 103)
	id 790801C911; Thu,  7 Aug 2003 12:47:41 +0100 (BST)
X-Original-To: group-post+cdbi-talk@soto.kasei.com
Delivered-To: group-post+cdbi-talk@soto.kasei.com
Received: by soto.kasei.com (Postfix, from userid 65534)
	id 8DF551C8FE; Thu,  7 Aug 2003 12:47:37 +0100 (BST)
Received: from mail03.svc.cra.dublin.eircom.net (mail03.svc.cra.dublin.eircom.net [159.134.118.19])
	by soto.kasei.com (Postfix) with SMTP id D181F1C8F5
	for <cdbi-talk@groups.kasei.com>; Thu,  7 Aug 2003 12:47:36 +0100 (BST)
Received: (qmail 1901 messnum 152866 invoked from network[159.134.167.25/p793.as1.limerick1.eircom.net]); 7 Aug 2003 11:47:35 -0000
Received: from p793.as1.limerick1.eircom.net (HELO dansat.data-plan.com) (159.134.167.25)
  by mail03.svc.cra.dublin.eircom.net (qp 1901) with SMTP; 7 Aug 2003 11:47:35 -0000
Received: from dansat.data-plan.com (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id h77BlY5Z048311;
	Thu, 7 Aug 2003 12:47:34 +0100 (BST)
	(envelope-from timbo@dansat.data-plan.com)
Received: (from timbo@localhost)
	by dansat.data-plan.com (8.12.9/8.12.9/Submit) id h77BlYup048310;
	Thu, 7 Aug 2003 12:47:34 +0100 (BST)
Date: Thu, 7 Aug 2003 12:47:34 +0100
From: Tim Bunce <Tim.Bunce@pobox.com>
To: Allen Day <allenday@ucla.edu>
Cc: cdbi-talk@groups.kasei.com
Subject: Re: v0.93 last_insert patch
Message-ID: <20030807114734.GE48122@dansat.data-plan.com>
References: <Pine.LNX.4.44.0303031226310.13477-100000@sumo.genetics.ucla.edu> <Pine.LNX.4.44.0308070249490.25490-200000@sumo.genetics.ucla.edu>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <Pine.LNX.4.44.0308070249490.25490-200000@sumo.genetics.ucla.edu>
User-Agent: Mutt/1.4i
X-Spam-Status: No, hits=-5.0 required=5.0
	tests=EMAIL_ATTRIBUTION,IN_REP_TO,QUOTED_EMAIL_TEXT,REFERENCES,
	      REPLY_WITH_QUOTES,USER_AGENT_MUTT
	version=2.55
X-Spam-Level: 
X-Spam-Checker-Version: SpamAssassin 2.55 (1.174.2.19-2003-05-19-exp)
X-Loop: cdbi-talk@groups.kasei.com
X-Sequence: 1677
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
Content-Length: 1063
Lines: 30

On Thu, Aug 07, 2003 at 02:51:33AM -0700, Allen Day wrote:
> Patch against Class::DBI 0.93 that attempts to find the last inserted PK 
> id into a table by examining the field's sequence.
> 
> -Allen

> *** DBI.pm	Wed Jul  2 03:48:40 2003
> --- DBI.pm.new	Thu Aug  7 02:46:57 2003
> ***************
> *** 481,486 ****
> --- 481,487 ----
>   
>   	# the DBI will provide a standard attribute soon, meanwhile...
>   	my $id = $dbh->{mysql_insertid}    # mysql
> + 		|| eval { ($dbh->selectrow_array("select last_value from ".$self->sequence))[0] } #Pg
>   		|| eval { $dbh->func('last_insert_rowid') };    # SQLite

Nooo!

That'll be very expensive for SQLite users and isn't a good way forward.

This code needs to be reworked to fetch $dbh->{Driver}->{Name} and use it
in if/elsif chain to decide which logic to apply. The current code didn't
do that simply because there wer only two choices and the first is very
cheap to call on the 'wrong' type of driver.

The code should also try calling the new $dbh->last_insert_id method that
DBI 1.38 will define.

Tim.

