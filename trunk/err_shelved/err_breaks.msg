From jkstill@cybcon.com  Tue Dec 31 07:38:25 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.6/8.12.6) with ESMTP id gBV7XPb8013025
	for <timbo@localhost>; Tue, 31 Dec 2002 07:35:15 GMT
	(envelope-from jkstill@cybcon.com)
Received: from pop3.mail.demon.net [194.217.242.59]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Tue, 31 Dec 2002 07:35:15 +0000 (GMT)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1041289078:10:05131:29; Mon, 30 Dec 2002 22:57:58 GMT
Received: from cali-2.pobox.com ([64.71.166.115]) by punt-1.mail.demon.net
           id aa1110567; 30 Dec 2002 22:57 GMT
Received: from cali-2.pobox.com (localhost.localdomain [127.0.0.1])
	by cali-2.pobox.com (Postfix) with ESMTP
	id D24653E6E6; Mon, 30 Dec 2002 17:57:45 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from watson.jks.com (dsl2-6.cybcon.net [208.186.116.6])
	by cali-2.pobox.com (Postfix) with ESMTP id 43E8F3E6AF
	for <Tim.Bunce@pobox.com>; Mon, 30 Dec 2002 17:57:44 -0500 (EST)
Received: from sherlock (jkstill@sherlock [192.168.1.101])
	by watson.jks.com (8.9.3/8.9.3) with SMTP id OAA05796;
	Mon, 30 Dec 2002 14:57:42 -0800
Content-Type: Multipart/Mixed;
  charset="iso-8859-1";
  boundary="------------Boundary-00=_6SFYUL87AJA1PFL8GFHV"
From: Jared Still <jkstill@cybcon.com>
To: Tim Bunce <Tim.Bunce@pobox.com>
Subject: Re: fetching with report breaks, totals and subtotals (was: More on testing cursors in Perl and PL/SQL)
Date: Mon, 30 Dec 2002 14:57:42 -0800
X-Mailer: KMail [version 1.2]
Cc: tl-pause@stlowery.net
References: <0212232112080A.07110@sherlock> <0212291811281E.07110@sherlock> <20021230120740.GA8565@dansat.data-plan.com>
In-Reply-To: <20021230120740.GA8565@dansat.data-plan.com>
MIME-Version: 1.0
Message-Id: <0212301457421K.07110@sherlock>
Status: RO
X-Status: A
Content-Length: 8127
Lines: 212


--------------Boundary-00=_6SFYUL87AJA1PFL8GFHV
Content-Type: text/plain;
  charset="iso-8859-1"
Content-Transfer-Encoding: 8bit


On Monday 30 December 2002 04:07, Tim Bunce wrote:

> On Sun, Dec 29, 2002 at 06:11:28PM -0800, Jared Still wrote:
> > One more thing:  One of my long time wished for modules is
> > one that emulates some of the more useful features of SQL*Plus,
> > namely report breaks, totals and subtotals.  I've finally actually
> > started on it.
> >
> > Would you be interested in seeing that?
> Yes. And the design/API as much, if not more, than the actual code.
>
> I know Tom Lowery is working on extending the DBI::Shell with
> sufficient functionality to emulate SQL*Plus.

I'll CC Tom Lowery on this.

>
> FYI, this entry has been in the DBI ToDo file for a few years:
>
> 	Add 'break handling' when field values change? Use two fbav's so 'previous
> 	record' is available. Define break fields and handlers. Call them via
> 	an alternate fetch_with_break method.
> 	Jan 2002: Also now see DBIx::FetchLoop (Brendan Fagan)
>
> Instead of a fetch_with_break method I think I'd rather add it as
> a feature of all fetch calls. And by "it" I just mean a generic
> "invoke callback on field change" mechanism that 'does the right thing'
> in terms of headers, footers, and correct 'break' handling. Add-on
> modules could then use that basic mechanism to implement totals and
> subtotals etc etc.
>
> Tim.


Sounds pretty much like what I'm doing.

The breaks are actually pretty easy to do, working
on objectizing (is that a verb?) it at the moment.

Took me awhile to get in the groove, as I haven't 
done any serious Perl for a few months.

When I have something worth discussing with others,
I'll make it available on the list.  It will still be alpha and
changable, but I like to actually have something to look
at and change if it isn't right, rather than endlessly 
discussing what it should be.

A starting point if you will, that actually has some traction.

Right now it's pretty simple.  Following is a piece of non-DBi
sample code.  The statement handle can be passed or
not, to be used for default format masks.

Many of the parameters are dummies, only the BREAKS
actually works at the moment.

The breaks are accomplished via a separate module that
is called by Tie::RPT, if there are columns to break on.

Though very useful to DBI, DBI is not required for this
to work.   For the moment at least, I'm keeping this as
generic as possible so that I only have to deal with issues
directly related to my objective.   i.e. I want to learn how
to make this work first, before making it a part of other
modules.

The 2 proto modules are attached.

Jared


use Tie::RPT;

my %data = (

   PRJSTAT => {
      PROJECT_TEAMS  => [qw{ COMMENT_PK  PERSON_PK }],
      PROJECT_VIEW   => [qw{ MEMBER_COMMENTS MEMBER_NAME PROJECT_COMMENTS 
PROJECT_NAME}],
      STATUS_HISTORIES  => [qw{ COMMENT_MILESTONE_PK COMMENT_RISK_PK 
COMMENT_STATUS_PK PERSON_PK PROJECT_PK STATUS STATUS_DATE}],
   },

   SCOTT => {
      AVG_SALARY_VIEW   => [qw{ AVG_SAL_DEPT DEPTNO }],
      BINCOL_TEST => [qw{ BINARY_DATA CLEAR_TEXT }],
      BONUS => [qw{ COMM ENAME JOB SAL }]
   },

);

my %pdata = ();
my @breaks=qw{ OWNER TABLE_NAME};

my $r = new Tie::RPT(
   \%pdata, # data container
   undef,   # \$sth if using DBI
   # COLUMNS args override $sth if present
   # column names and format field
   COLUMNS => {
      OWNER => '@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<',
      TABLE_NAME => '@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<',
      COLUMN_NAME => '@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<',
   },

   BREAKS => [qw{OWNER TABLE_NAME}],
   PAGESIZE => 60,
   LINESIZE => 100,

);

foreach my $towner ( keys %data ) {
   $pdata{OWNER}=$towner;
   foreach my $tname ( keys %{$data{$towner}} ) {
      $pdata{TABLE_NAME}=$tname;
      foreach my $col ( @{$data{$towner}->{$tname}} ) {
         $pdata{COLUMN_NAME}=$col;
         printf "%15s %30s %30s\n",
            $pdata{OWNER}
            , $pdata{TABLE_NAME}
            , $pdata{COLUMN_NAME};
      }
   }
}


OUTPUT:

     SCOTT                BONUS                 COMM
                                               ENAME
                                                 JOB
                                                 SAL
                AVG_SALARY_VIEW         AVG_SAL_DEPT
                                              DEPTNO
                    BINCOL_TEST          BINARY_DATA
                                          CLEAR_TEXT
   PRJSTAT     STATUS_HISTORIES COMMENT_MILESTONE_PK
                                     COMMENT_RISK_PK
                                   COMMENT_STATUS_PK
                                           PERSON_PK
                                          PROJECT_PK
                                              STATUS
                                         STATUS_DATE
                  PROJECT_TEAMS           COMMENT_PK
                                           PERSON_PK
                   PROJECT_VIEW      MEMBER_COMMENTS
                                         MEMBER_NAME
                                    PROJECT_COMMENTS
                                        PROJECT_NAME





--------------Boundary-00=_6SFYUL87AJA1PFL8GFHV
Content-Type: text/plain;
  charset="iso-8859-1";
  name="RPT.pm"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="RPT.pm"

CnBhY2thZ2UgVGllOjpSUFQ7Cgp1c2UgRGF0YTo6RHVtcGVyOwoKdXNlIHN0cmljdDsKdXNlIHZh
cnMgcXcoQElTQSAkVkVSU0lPTik7CnVzZSBUaWU6OlJQVDo6QnJlYWs7CiRWRVJTSU9OID0gJzAu
MDEnOwpASVNBID0gcXcoVGllOjpTdGRIYXNoKTsKCiRUaWU6OlJQVDo6ZGVidWcgPSAwOwoKc3Vi
IG5ldyB7CglteSAkcGtnID0gc2hpZnQ7CglteSAkY2xhc3MgPSByZWYoJHBrZykgfHwgJHBrZzsK
CglteSAoJGhkYXRhLCAkcnN0aCwgJWFyZ3MgKSA9IEBfOwoKCXRpZSAleyRoZGF0YX0sICJUaWU6
OlJQVDo6QnJlYWsiLCBAeyRhcmdze0JSRUFLU319OwoKCWJsZXNzIFwlYXJncywgJGNsYXNzOwoK
fQoKIy0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCgoKCjE7CgoK

--------------Boundary-00=_6SFYUL87AJA1PFL8GFHV
Content-Type: text/plain;
  charset="iso-8859-1";
  name="Break.pm"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="Break.pm"

CnBhY2thZ2UgVGllOjpSUFQ6OkJyZWFrOwoKdXNlIERhdGE6OkR1bXBlcjsKCnVzZSBzdHJpY3Q7
CnVzZSB2YXJzIHF3KEBJU0EgJFZFUlNJT04pOwp1c2UgVGllOjpIYXNoOwokVkVSU0lPTiA9ICcw
LjAxJzsKQElTQSA9IHF3KFRpZTo6U3RkSGFzaCk7Cgp1c2UgdmFycyBxdygkZGVidWcpOwokVGll
OjpSUFQ6OkJyZWFrOjpkZWJ1ZyA9IDA7CgolVGllOjpSUFQ6Om5ld0JyZWFrVmFscz0oKTsKJVRp
ZTo6UlBUOjpvbGRCcmVha1ZhbHM9KCk7CkBUaWU6OlJQVDo6QnJlYWtDb2xzPSgpOwoKc3ViIFRJ
RUhBU0ggewoJbXkgKCRjbGFzcyxAYnJlYWtzKSA9IEBfOwoKCWlmICgkVGllOjpSUFQ6OmRlYnVn
KSB7CgkJcHJpbnQgIlRJRUhBU0ghXG4iIDsKCQlwcmludCAiQnJlYWtzOiAiLCBEdW1wZXIoXEBi
cmVha3MpLCAiXG4iOwoJfQoKCUBUaWU6OlJQVDo6QnJlYWtDb2xzID0gQGJyZWFrczsKCSMgcHJp
bnQgIlRJRUhBU0ghICIsIER1bXBlcihcJVRpZTo6UlBUOjpvbGRCcmVha1ZhbHMpLCAiXG4iOwoJ
Ymxlc3Mge30sICAkY2xhc3M7Cn0KCnN1YiBTVE9SRSB7CglteSgkaW1wbCwgJGtleSwgJG5ld3Zh
bCkgPSBAXzsKCXByaW50ICJTVE9SRSFcbiIgaWYgJFRpZTo6UlBUOjpkZWJ1ZzsKCSMkaW1wbC0+
eyRrZXl9ID0ge2tleT0+JGtleSwgdmFsdWU9PiRuZXd2YWx9OwoJJGltcGwtPnska2V5fSA9ICRu
ZXd2YWw7Cn0KCnN1YiBGRVRDSCB7CglteSgkaW1wbCwgJGtleSkgPSBAXzsKCgkkVGllOjpSUFQ6
Om5ld0JyZWFrVmFsc3ska2V5fSA9ICRpbXBsLT57JGtleX07CgoJJFRpZTo6UlBUOjpvbGRCcmVh
a1ZhbHN7JGtleX0gPSAnJwoJCXVubGVzcyBkZWZpbmVkKCRUaWU6OlJQVDo6b2xkQnJlYWtWYWxz
eyRrZXl9KTsKCQkKCglpZiAoICRUaWU6OlJQVDo6ZGVidWcgKSB7CgkJcHJpbnQgIkZFVENIIVxu
IjsKCQlwcmludCAiRkVUQ0gga2V5OiAka2V5XG4iOwoJCXByaW50ICJGRVRDSCBrZXlzOiAiLCBq
b2luKCc6JyxAVGllOjpSUFQ6OkJyZWFrQ29scyksICJcbiI7CgkJcHJpbnQgIk5FVzogJFRpZTo6
UlBUOjpuZXdCcmVha1ZhbHN7JGtleX1cbiI7CgkJcHJpbnQgIk9MRDogJFRpZTo6UlBUOjpvbGRC
cmVha1ZhbHN7JGtleX1cbiI7Cgl9CgoJaWYgKCBncmVwKC8ka2V5LywgQFRpZTo6UlBUOjpCcmVh
a0NvbHMpKSB7CgkJaWYgKCAkVGllOjpSUFQ6Om5ld0JyZWFrVmFsc3ska2V5fSBlcSAkVGllOjpS
UFQ6Om9sZEJyZWFrVmFsc3ska2V5fSApIHsKCQkJcHJpbnQgIlx0RkVUQ0ggRVFcbiIgaWYgJFRp
ZTo6UlBUOjpkZWJ1ZzsKCQkJJGltcGwtPnska2V5fT0nJzsKCQl9IGVsc2UgewoJCQlwcmludCAi
XHRGRVRDSCBORVFcbiIgaWYgJFRpZTo6UlBUOjpkZWJ1ZzsKCQkJJFRpZTo6UlBUOjpvbGRCcmVh
a1ZhbHN7JGtleX0gPSAkaW1wbC0+eyRrZXl9OwoJCQkjcmV0dXJuICRpbXBsLT57JGtleX07CgkJ
fQoJfQoJcmV0dXJuICRpbXBsLT57JGtleX07Cn0KCjE7Cgo=

--------------Boundary-00=_6SFYUL87AJA1PFL8GFHV--

