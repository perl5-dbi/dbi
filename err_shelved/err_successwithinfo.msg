From dbi-users-return-12265-Tim.Bunce=pobox.com@perl.org  Tue Jun 25 13:07:08 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g5PC77o69717
	for <timbo@localhost>; Tue, 25 Jun 2002 13:07:07 +0100 (BST)
	(envelope-from dbi-users-return-12265-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.59]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Tue, 25 Jun 2002 13:07:07 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1024999579:10:23375:115; Tue, 25 Jun 2002 10:06:19 GMT
Received: from cali-2.pobox.com ([64.71.166.115]) by punt-1.mail.demon.net
           id aa1113555; 25 Jun 2002 10:06 GMT
Received: from cali-2.pobox.com (localhost.localdomain [127.0.0.1])
	by cali-2.pobox.com (Postfix) with ESMTP id 21C833E693
	for <Tim.Bunce@data-plan.com>; Tue, 25 Jun 2002 06:01:14 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [64.70.54.95])
	by cali-2.pobox.com (Postfix) with SMTP id AE0963E694
	for <Tim.Bunce@pobox.com>; Tue, 25 Jun 2002 06:01:13 -0400 (EDT)
Received: (qmail 43655 invoked by uid 1005); 25 Jun 2002 10:05:01 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 43640 invoked by uid 76); 25 Jun 2002 10:05:00 -0000
Received: from mail05.svc.cra.dublin.eircom.net (HELO mail05.svc.cra.dublin.eircom.net) (159.134.118.21)
  by onion.perl.org (qpsmtpd/0.07b) with SMTP; Tue Jun 25 10:05:00 2002 -0000
Received: (qmail 98741 messnum 357937 invoked from network[159.134.167.72/p840.as1.limerick1.eircom.net]); 25 Jun 2002 09:59:50 -0000
Received: from p840.as1.limerick1.eircom.net (HELO dansat.data-plan.com) (159.134.167.72)
  by mail05.svc.cra.dublin.eircom.net (qp 98741) with SMTP; 25 Jun 2002 09:59:50 -0000
Received: (from timbo@localhost)
	by dansat.data-plan.com (8.11.6/8.11.6) id g5P9xo968632;
	Tue, 25 Jun 2002 10:59:50 +0100 (BST)
	(envelope-from timbo)
Date: Tue, 25 Jun 2002 10:59:50 +0100
From: Tim Bunce <Tim.Bunce@pobox.com>
To: Reddy Thalakola <reddyt@yahoo-inc.com>
Cc: dbi-users <dbi-users@perl.org>
Subject: Re: strange error with using $db->do
Message-ID: <20020625105950.L87029@dansat.data-plan.com>
References: <NEBBLPOIMMCKNMNLFKGMGEODEMAA.reddyt@yahoo-inc.com> <NEBBLPOIMMCKNMNLFKGMGEOHEMAA.reddyt@yahoo-inc.com>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
User-Agent: Mutt/1.2.5i
In-Reply-To: <NEBBLPOIMMCKNMNLFKGMGEOHEMAA.reddyt@yahoo-inc.com>; from reddyt@yahoo-inc.com on Mon, Jun 24, 2002 at 03:01:03PM -0700
Status: RO
Content-Length: 1253
Lines: 35

On Mon, Jun 24, 2002 at 03:01:03PM -0700, Reddy Thalakola wrote:
> I have cron script that runs fine on a bsd machine, but returns this output
> on the linux machine.
> 
> i have version 1.21 on the linux machine.
> 
> DBD::Oracle::db do failed: ORA-00000: normal, successful completion (DBD
> SUCCESS_WITH_INFO: OCIStmtExecute) at
> /home/scripts/update/recompilestoredprocedures line 33.
> 
> here is the code:
> 
> while (my ($oname,$otype) =  $select->fetchrow_array) {
>     $sql = "ALTER $otype $oname COMPILE";
>     unless ( $db->do($sql)) { ## this db statement generates the eror
>         $objectsnotcompiled = $objectsnotcompiled .  $oname . ' ';
>     }
> }

The DBI needs some standard way to handle the 'success with info' concept.
Meanwhile:

:  Changes in DBD::Oracle 1.09   27th August 2001
: 
:    Changed behaviour when OCIStmtExecute() returns OCI_SUCCESS_WITH_INFO:
:      used to be treated as OCI_SUCCESS, now also sets $DBI::err/$DBI::errstr
:      and will therefore trigger RaiseError/PrintError if they are set.

So you can either disable RaiseError/PrintError for that statement or
just wrap an eval { ... } around it (probably better).

The OCI_SUCCESS_WITH_INFO is probably due to PL/SQL warnings from the COMPILE.

Tim.


