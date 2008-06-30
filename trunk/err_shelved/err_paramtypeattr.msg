From dbi-users-return-18973-Tim.Bunce=pobox.com@perl.org  Fri Jun 13 13:41:57 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id h5DCc13p094355
	for <timbo@localhost>; Fri, 13 Jun 2003 13:41:56 +0100 (BST)
	(envelope-from dbi-users-return-18973-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 13 Jun 2003 13:41:56 +0100 (BST)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1055496595:20:08218:17; Fri, 13 Jun 2003 09:29:55 GMT
Received: from puzzle.pobox.com ([207.106.49.20]) by punt-2.mail.demon.net
           id aa2108963; 13 Jun 2003 9:29 GMT
Received: from puzzle.pobox.com (localhost [127.0.0.1])
	by puzzle.pobox.com (Postfix) with ESMTP id E0F8826C0C0
	for <Tim.Bunce@data-plan.com>; Fri, 13 Jun 2003 05:29:37 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [64.70.54.95])
	by puzzle.pobox.com (Postfix) with SMTP id 7680B26C2F9
	for <Tim.Bunce@pobox.com>; Fri, 13 Jun 2003 05:29:37 -0400 (EDT)
Received: (qmail 84076 invoked by uid 1005); 13 Jun 2003 09:28:29 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 83995 invoked by uid 76); 13 Jun 2003 09:28:27 -0000
Received: from qmailr@one.develooper.com (HELO ran-out.mx.develooper.com) (64.81.84.115) by onion.perl.org (qpsmtpd/0.26) with SMTP; Fri, 13 Jun 2003 02:28:27 -0700
Received: (qmail 4047 invoked by uid 225); 13 Jun 2003 09:27:36 -0000
Delivered-To: dbi-users@perl.org
Received: (qmail 4015 invoked by uid 507); 13 Jun 2003 09:27:32 -0000
Received: from mail03.svc.cra.dublin.eircom.net (HELO mail03.svc.cra.dublin.eircom.net) (159.134.118.19) by one.develooper.com (qpsmtpd/0.26) with SMTP; Fri, 13 Jun 2003 02:27:31 -0700
Received: (qmail 77474 messnum 3719254 invoked from network[159.134.165.197/p453.as1.limerick1.eircom.net]); 13 Jun 2003 09:27:41 -0000
Received: from p453.as1.limerick1.eircom.net (HELO dansat.data-plan.com) (159.134.165.197)  by mail03.svc.cra.dublin.eircom.net (qp 77474) with SMTP; 13 Jun 2003 09:27:41 -0000
Received: from dansat.data-plan.com (localhost [127.0.0.1])	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id h5D9Rh0p084228;	Fri, 13 Jun 2003 10:27:43 +0100 (BST)	(envelope-from timbo@dansat.data-plan.com)
Received: (from timbo@localhost)	by dansat.data-plan.com (8.12.9/8.12.9/Submit) id h5D9RhnU084227;	Fri, 13 Jun 2003 10:27:43 +0100 (BST)
Date: Fri, 13 Jun 2003 10:27:43 +0100
From: Tim Bunce <Tim.Bunce@pobox.com>
To: Steven Lembark <lembark@wrkhors.com>
Cc: dbi-users <dbi-users@perl.org>
Subject: Re: Query formatting problem
Message-ID: <20030613092743.GM77623@dansat.data-plan.com>
References: <47410000.1055436905@getz.wrkhors.com>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <47410000.1055436905@getz.wrkhors.com>
User-Agent: Mutt/1.4i
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=-1.9 required=7.0 tests=CARRIAGE_RETURNS,IN_REP_TO,REFERENCES,SPAM_PHRASE_00_01,USER_AGENT,USER_AGENT_MUTT version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Status: RO
Content-Length: 2322
Lines: 69

On Thu, Jun 12, 2003 at 11:55:05AM -0500, Steven Lembark wrote:

> Using the placeholders makes my life simpler since the
> name and value are taken from the same variable but
> DBI handles the stringy/numeric issues for itself. The
> problem starts when admin's have to check why something
> failed at 3am and don't know that the '?' are replaced
> as '500' followed by a naked 500 (for $a) and then the
> date in quotes.
> 
> What I need is something like:
> 	my $a = 500;
> 	my $date = '11-Jul-1999';
> 	$string = $sth->interpolated( $sql, $a, $a, $date )
> 
> gives me back:
> 		name = "500"
> 		and
> 		value = 500
> 		and
> 		date = "11-Jul-1999"
> 
> The main issue is being able to walk the bind param. list
> and check if the columns are numeric (naked copy of $a + 0
> inserted) or not (quoted copy of $a).

It's not quite that simple.

> The alternative is having to sprintf every query I use
> for each combination of values and $dbh->do() them for
> large datasets in case any one of them fails (ugh!).
> 
> Looking throught he DBI-1.38 pod, the Catalog Methods
> don't have anything quite like this since there is no
> way to query what DBI thinks of the bound parameters

There is the $sth->{ParamValues} attribute.

I could add an $sth->{ParamTypes} attribute. Patches welcome!

[Would be a hash with the same keys as ParamValues. The hash values
would be either an integer SQL_* type value, like SQL_VARCHAR, or
a ref to a hash that included a TYPE => SQL_* type value pair, plus
anything else that was passed at the third arg to bind_param()]

> An ideal would be some sort of $dbh->blah that returned
> the stringified version of whatever query was run last:
> 
> 	die join "\n",
> 		'Bad news, boss:',
> 		$dbh->errstr,
> 		$dbh->last_query
> 	;
> 
> If there is someplace w/in the SQL modules that has this
> please warn me, so far wandering through CPAN hasn't
> gotten me anywhere.

It's not done because it's far from trivial to "do it right".

"The Plan" is that the (undocumented) preparse method can be asked
to return the query reformatted into a sprintf string, into which
you can then fairly easily plug the bind values - but you'd have to
look after any quoting for each.

An extra method could then be added to do that for you and then the
driver could override that if it needed to.

Tim.

