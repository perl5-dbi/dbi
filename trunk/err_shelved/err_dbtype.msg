From datetime-return-3604-timbo=dansat.data-plan.com@perl.org  Thu Jul 17 07:30:28 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id h6H6UC5p054442
	for <timbo@localhost>; Thu, 17 Jul 2003 07:30:28 +0100 (BST)
	(envelope-from datetime-return-3604-timbo=dansat.data-plan.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Thu, 17 Jul 2003 07:30:28 +0100 (BST)
Received: from punt-3.mail.demon.net by mailstore
          for timbo@dansat.data-plan.com id 19cvwf-1-5lT-7;
          Wed, 16 Jul 2003 23:44:25 -0000
Received: from onion.valueclick.com ([64.70.54.95]) by punt-3.mail.demon.net
           id aa0120427; 16 Jul 2003 23:43 GMT
Received: (qmail 30724 invoked by uid 1005); 16 Jul 2003 23:43:50 -0000
Mailing-List: contact datetime-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:datetime@perl.org>
List-Help: <mailto:datetime-help@perl.org>
List-Unsubscribe: <mailto:datetime-unsubscribe@perl.org>
List-Subscribe: <mailto:datetime-subscribe@perl.org>
Delivered-To: mailing list datetime@perl.org
Received: (qmail 30709 invoked by uid 1012); 16 Jul 2003 23:43:50 -0000
To: datetime@perl.org
Date: 17 Jul 2003 01:16:00 +0200
From: claus@faerber.muc.de (=?ISO-8859-1?Q?Claus_F=E4rber?=)
Message-ID: <8q3s6UwocDD@perl.3247.org>
References: <20030716173843.GA167@alva.zevenwouden.nl>
	<Pine.GSO.4.44.0307160947550.15849-100000@tiu>
	<20030716200342.GA368@alva.zevenwouden.nl>
Subject: Re: DT::F::DBI docs
User-Agent: OpenXP/32 v3.9.7 (Win32) alpha @ 2003-07-16-1354d
MIME-Version: 1.0
Content-Type: text/plain; charset=US-ASCII
X-Posted-By: 217.235.246.210
Status: RO
X-Status: A
Content-Length: 1721
Lines: 75

Eugene Van Der Pijll <pijll@gmx.net> schrieb/wrote:
> Joshua Hoblitt schreef:
>> If X has identical date/time handling as Pg I'd like to see DT::F::X
>> be isa DT::F::Pg.  Otherwise things might get a bit confusion for end
>> users.
> Hmmm. I count 47 different DBD modules. That means 47 DT::F modules?

Let's see.

The following databases will probably need full support (although some
will probably have compatible formats):

  DBD::ASAny
  DBD::DB2
  DBD::Empress
  DBD::Illustra
  DBD::Informix
  DBD::Ingres
  DBD::InterBase
  DBD::Oracle
  DBD::Ovrimos (still listed as DBD::Altera on search.CPAN.org)
  DBD::PrimeBase
  DBD::QBase
  DBD::RBD
  DBD::Solid
  DBD::Sqlflex
  DBD::Sybase
  DBD::Unify
  DBD::mSQL
  DBD::mysql

The follwing are aliases/alternative implementations for other database
types and don't need an own implementation:

  DBD::Altera           => DBD::Ovrimos
  DBD::PgPP             => DBD::Pg
  DBD::mysqlPP          => DBD::mysql

The following databases are untyped (i.e. we need to make up a format --
standard SQL92 -- and just use):

  DBD::CSV
  DBD::RAM
  DBD::Sprite
  DBD::XBase

The following are not real databases and handle SQL internally (and
hopefully use standard SQL and only standard SQL for dates):

  DBD::Excel (not implemented)
  DBD::SearchServer

The follwing drivers don't handle dates at all:

  DBD::Google

The follwing are just connectors to other APIs or proxies: They will use
the format of the database they are actually connected to:

  DBD::ADO (?)
  DBD::ODBC
  DBD::Multiplex
  DBD::ODBC
  DBD::Recall
  DBD::SQLRelay
  DBD::pNET

Modules that seem to be outdated/unmaintained anyway:

  DBD::DtfSQLmac
  DBD::FreeTDS

Claus
-- 
http://www.faerber.muc.de

From datetime-return-3618-timbo=dansat.data-plan.com@perl.org  Thu Jul 17 15:40:24 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id h6HEe75i058470
	for <timbo@localhost>; Thu, 17 Jul 2003 15:40:24 +0100 (BST)
	(envelope-from datetime-return-3618-timbo=dansat.data-plan.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Thu, 17 Jul 2003 15:40:24 +0100 (BST)
Received: from punt-3.mail.demon.net by mailstore
          for timbo@dansat.data-plan.com id 19d8Og-3-1cj-5;
          Thu, 17 Jul 2003 13:02:10 -0000
Received: from onion.valueclick.com ([64.70.54.95]) by punt-3.mail.demon.net
           id aa0303940; 17 Jul 2003 13:01 GMT
Received: (qmail 67568 invoked by uid 1005); 17 Jul 2003 13:01:35 -0000
Mailing-List: contact datetime-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:datetime@perl.org>
List-Help: <mailto:datetime-help@perl.org>
List-Unsubscribe: <mailto:datetime-unsubscribe@perl.org>
List-Subscribe: <mailto:datetime-subscribe@perl.org>
Delivered-To: mailing list datetime@perl.org
Received: (qmail 67549 invoked by uid 76); 17 Jul 2003 13:01:35 -0000
Delivered-To: datetime@perl.org
Received-SPF: unknown
Date: Thu, 17 Jul 2003 14:01:15 +0100
From: Tim Bunce <Tim.Bunce@pobox.com>
To: Claus =?iso-8859-1?Q?F=E4rber?= <claus@faerber.muc.de>
Cc: datetime@perl.org
Subject: Re: DT::F::DBI docs
Message-ID: <20030717130115.GJ53123@dansat.data-plan.com>
References: <20030716173843.GA167@alva.zevenwouden.nl> <Pine.GSO.4.44.0307160947550.15849-100000@tiu> <20030716200342.GA368@alva.zevenwouden.nl> <8q3s6UwocDD@perl.3247.org>
Mime-Version: 1.0
Content-Type: text/plain; charset=iso-8859-1
Content-Disposition: inline
Content-Transfer-Encoding: 8bit
In-Reply-To: <8q3s6UwocDD@perl.3247.org>
User-Agent: Mutt/1.4i
X-SMTPD: qpsmtpd/0.27-dev, http://develooper.com/code/qpsmtpd/
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=-2.7 required=7.0 tests=CARRIAGE_RETURNS,IN_REP_TO,QUOTED_EMAIL_TEXT,REFERENCES,SPAM_PHRASE_00_01,USER_AGENT,USER_AGENT_MUTT version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Status: RO
Content-Length: 2424
Lines: 90

The DBI has a (currently private) method to determine the underlying
database type. It was borrowed from DBIx::AnyDBD. Take a look at
_dbtype_names() in DBI.pm

I intend to extend it to use $dbh->get_info(17); (=SQL_DBMS_NAME),
and give it a public api, in the medium term.

I think it would be wise to keep in sync with that code,
and the best way to do that would be to actually use that code,
and the best way to do that would be to send me patches for
any changes you may need...

Tim.

On Thu, Jul 17, 2003 at 01:16:00AM +0200, Claus Färber wrote:
> Eugene Van Der Pijll <pijll@gmx.net> schrieb/wrote:
> > Joshua Hoblitt schreef:
> >> If X has identical date/time handling as Pg I'd like to see DT::F::X
> >> be isa DT::F::Pg.  Otherwise things might get a bit confusion for end
> >> users.
> > Hmmm. I count 47 different DBD modules. That means 47 DT::F modules?
> 
> Let's see.
> 
> The following databases will probably need full support (although some
> will probably have compatible formats):
> 
>   DBD::ASAny
>   DBD::DB2
>   DBD::Empress
>   DBD::Illustra
>   DBD::Informix
>   DBD::Ingres
>   DBD::InterBase
>   DBD::Oracle
>   DBD::Ovrimos (still listed as DBD::Altera on search.CPAN.org)
>   DBD::PrimeBase
>   DBD::QBase
>   DBD::RBD
>   DBD::Solid
>   DBD::Sqlflex
>   DBD::Sybase
>   DBD::Unify
>   DBD::mSQL
>   DBD::mysql
> 
> The follwing are aliases/alternative implementations for other database
> types and don't need an own implementation:
> 
>   DBD::Altera           => DBD::Ovrimos
>   DBD::PgPP             => DBD::Pg
>   DBD::mysqlPP          => DBD::mysql
> 
> The following databases are untyped (i.e. we need to make up a format --
> standard SQL92 -- and just use):
> 
>   DBD::CSV
>   DBD::RAM
>   DBD::Sprite
>   DBD::XBase
> 
> The following are not real databases and handle SQL internally (and
> hopefully use standard SQL and only standard SQL for dates):
> 
>   DBD::Excel (not implemented)
>   DBD::SearchServer
> 
> The follwing drivers don't handle dates at all:
> 
>   DBD::Google
> 
> The follwing are just connectors to other APIs or proxies: They will use
> the format of the database they are actually connected to:
> 
>   DBD::ADO (?)
>   DBD::ODBC
>   DBD::Multiplex
>   DBD::ODBC
>   DBD::Recall
>   DBD::SQLRelay
>   DBD::pNET
> 
> Modules that seem to be outdated/unmaintained anyway:
> 
>   DBD::DtfSQLmac
>   DBD::FreeTDS
> 
> Claus
> -- 
> http://www.faerber.muc.de

From datetime-return-3684-timbo=dansat.data-plan.com@perl.org  Mon Jul 21 07:33:16 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id h6L6UI83092835
	for <timbo@localhost>; Mon, 21 Jul 2003 07:33:16 +0100 (BST)
	(envelope-from datetime-return-3684-timbo=dansat.data-plan.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Mon, 21 Jul 2003 07:33:16 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for timbo@dansat.data-plan.com
          id 1058735940:10:07622:21; Sun, 20 Jul 2003 21:19:00 GMT
Received: from onion.valueclick.com ([64.70.54.95]) by punt-1.mail.demon.net
           id aa1126356; 20 Jul 2003 21:18 GMT
Received: (qmail 8594 invoked by uid 1005); 20 Jul 2003 21:18:35 -0000
Mailing-List: contact datetime-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:datetime@perl.org>
List-Help: <mailto:datetime-help@perl.org>
List-Unsubscribe: <mailto:datetime-unsubscribe@perl.org>
List-Subscribe: <mailto:datetime-subscribe@perl.org>
Delivered-To: mailing list datetime@perl.org
Received: (qmail 8579 invoked by uid 1012); 20 Jul 2003 21:18:35 -0000
To: datetime@perl.org
Date: 20 Jul 2003 22:53:00 +0200
From: claus@faerber.muc.de (=?ISO-8859-1?Q?Claus_F=E4rber?=)
Message-ID: <8qCDpTbJcDD@perl.3247.org>
References: <20030716173843.GA167@alva.zevenwouden.nl>
	<Pine.GSO.4.44.0307160947550.15849-100000@tiu>
	<20030716200342.GA368@alva.zevenwouden.nl> <8q3s6UwocDD@perl.3247.org>
	<20030717130115.GJ53123@dansat.data-plan.com>
Subject: Re: DT::F::DBI docs
User-Agent: OpenXP/32 v3.9.7 (Win32) alpha @ 2003-07-16-1354d
MIME-Version: 1.0
Content-Type: text/plain; charset=US-ASCII
X-Posted-By: 217.235.223.85
Status: RO
Content-Length: 952
Lines: 26

Tim Bunce <Tim.Bunce@pobox.com> schrieb/wrote:
> The DBI has a (currently private) method to determine the underlying
> database type. It was borrowed from DBIx::AnyDBD. Take a look at
> _dbtype_names() in DBI.pm

Yeah, I just updated DT::F::DBI to use that function.

> I intend to extend it to use $dbh->get_info(17); (=SQL_DBMS_NAME),
> and give it a public api, in the medium term.

One of the problems I can see is that it just returns the type ODBC
returns, which is already a problem for MySQL (returns /^mysqld-.*/[1])  
and PostgreSQL (returns 'PostgreSQL', not 'Pg'[1]).
I'm not sure what DBD::PgPP and DBD::PgSPI return, either.

Maybe DBI::_dbtype_names should normalise these DBMS names (e.g. to the  
corresponding DBD::* driver name, if one exists).

BTW, is there a CVS server for DBI somewhere?

Claus

[1] I have only looked at unixODBC's source code and not installed it,
    so I might be wrong there.
-- 
http://www.faerber.muc.de

From datetime-return-3707-timbo=dansat.data-plan.com@perl.org  Tue Jul 22 18:35:57 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id h6MHUN9j003490
	for <timbo@localhost>; Tue, 22 Jul 2003 18:35:56 +0100 (BST)
	(envelope-from datetime-return-3707-timbo=dansat.data-plan.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Tue, 22 Jul 2003 18:35:56 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for timbo@dansat.data-plan.com
          id 1058868036:10:08851:2; Tue, 22 Jul 2003 10:00:36 GMT
Received: from onion.valueclick.com ([64.70.54.95]) by punt-1.mail.demon.net
           id aa1121040; 22 Jul 2003 10:00 GMT
Received: (qmail 43624 invoked by uid 1005); 22 Jul 2003 09:59:30 -0000
Mailing-List: contact datetime-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:datetime@perl.org>
List-Help: <mailto:datetime-help@perl.org>
List-Unsubscribe: <mailto:datetime-unsubscribe@perl.org>
List-Subscribe: <mailto:datetime-subscribe@perl.org>
Delivered-To: mailing list datetime@perl.org
Delivered-To: moderator for datetime@perl.org
Received: (qmail 65284 invoked by uid 76); 21 Jul 2003 22:18:25 -0000
Delivered-To: datetime@perl.org
Received-SPF: unknown
MIME-Version: 1.0
Date: Mon, 21 Jul 2003 23:17:37 +0100
To: =?iso-8859-15?Q?Claus_F=E4rber?= <claus@faerber.muc.de>, datetime@perl.org
Subject: Re: DT::F::DBI docs
Content-Type: text/plain; charset=iso-8859-15; format=flowed
References: <20030716173843.GA167@alva.zevenwouden.nl> <Pine.GSO.4.44.0307160947550.15849-100000@tiu> <20030716200342.GA368@alva.zevenwouden.nl> <8q3s6UwocDD@perl.3247.org> <20030717130115.GJ53123@dansat.data-plan.com> <8qCDpTbJcDD@perl.3247.org>
From: Tim Bunce <Tim.Bunce@pobox.com>
Message-ID: <oprsoljncjbt4drx@localhost>
In-Reply-To: <8qCDpTbJcDD@perl.3247.org>
User-Agent: Opera7.0/Win32 M2 build 2637
X-SMTPD: qpsmtpd/0.27-dev, http://develooper.com/code/qpsmtpd/
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=0.1 required=7.0 tests=CARRIAGE_RETURNS,IN_REP_TO,QUOTED_EMAIL_TEXT,RCVD_IN_MULTIHOP_DSBL,RCVD_IN_UNCONFIRMED_DSBL,REFERENCES,SPAM_PHRASE_00_01,USER_AGENT version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Status: RO
Content-Length: 1339
Lines: 41

On 20 Jul 2003 22:53:00 +0200, Claus Frber <claus@xn--frber-gra.muc.de> wrote:

> Tim Bunce <Tim.Bunce@pobox.com> schrieb/wrote:
>> The DBI has a (currently private) method to determine the underlying
>> database type. It was borrowed from DBIx::AnyDBD. Take a look at
>> _dbtype_names() in DBI.pm
>
> Yeah, I just updated DT::F::DBI to use that function.
>
>> I intend to extend it to use $dbh->get_info(17); (=SQL_DBMS_NAME),
>> and give it a public api, in the medium term.
>
> One of the problems I can see is that it just returns the type ODBC
> returns, which is already a problem for MySQL (returns /^mysqld-.*/[1])

That is an issue. But that's part of the reason why _dbtype_names()
returns an ordered list. For "mysqld-foo-bar" it may return something
like ("mysqld-foo-bar", "mysqld-foo", "mysqld").

> and PostgreSQL (returns 'PostgreSQL', not 'Pg'[1]).
> I'm not sure what DBD::PgPP and DBD::PgSPI return, either.

> Maybe DBI::_dbtype_names should normalise these DBMS names
> (e.g. to the  corresponding DBD::* driver name, if one exists).

More likely that the DBI would supply a module that provides mapping
between the sets of names.

> BTW, is there a CVS server for DBI somewhere?

No. One day...

Tim.

> Claus
>
> [1] I have only looked at unixODBC's source code and not installed it,
> so I might be wrong there.




