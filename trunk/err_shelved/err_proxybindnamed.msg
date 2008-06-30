From ome@webcom.de  Fri Dec 14 07:31:22 2001
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id fBE7VLN56647
	for <timbo@localhost>; Fri, 14 Dec 2001 07:31:21 GMT
	(envelope-from ome@webcom.de)
Received: from pop3.mail.demon.net [194.217.242.59]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 14 Dec 2001 07:31:21 +0000 (GMT)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1008266036:10:05019:1; Thu, 13 Dec 2001 17:53:56 GMT
Received: from cali-2.pobox.com ([64.71.166.115]) by punt-1.mail.demon.net
           id aa1004659; 13 Dec 2001 17:53 GMT
Received: from cali-2.pobox.com (localhost.localdomain [127.0.0.1])
	by cali-2.pobox.com (Postfix) with ESMTP id 989F83E800
	for <Tim.Bunce@data-plan.com>; Thu, 13 Dec 2001 12:53:05 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from arane.webcom.de (unknown [217.110.202.132])
	by cali-2.pobox.com (Postfix) with ESMTP id D69A03E7B6
	for <Tim.Bunce@pobox.com>; Thu, 13 Dec 2001 12:52:15 -0500 (EST)
Received: from omenotebook (p78.n78.dip.aha.ru [195.2.78.78])
	by arane.webcom.de (Postfix) with ESMTP id A96871729D
	for <Tim.Bunce@pobox.com>; Thu, 13 Dec 2001 18:51:00 +0100 (MET)
From: "Oleg Mechtcheriakov" <ome@webcom.de>
To: "'Tim Bunce'" <Tim.Bunce@pobox.com>
Subject: RE: :Proxy and bind_param (with ORACLE)
Date: Thu, 13 Dec 2001 18:43:47 +0100
Message-ID: <001f01c183fe$447c1940$9b4e02c3@webcom.de>
MIME-Version: 1.0
Content-Type: text/plain;
	charset="iso-8859-1"
Content-Transfer-Encoding: 7bit
X-Priority: 3 (Normal)
X-MSMail-Priority: Normal
X-Mailer: Microsoft Outlook CWS, Build 9.0.2416 (9.0.2911.0)
Importance: Normal
X-MimeOLE: Produced By Microsoft MimeOLE V5.50.4522.1200
In-Reply-To: <20011213160038.A49031@dansat.data-plan.com>
Status: RO
Content-Length: 7257
Lines: 236

Hi, Tim,

thanks for Your mail.

Unfortunately I've changed the project, the job and the programming language
since then, so now I cannot add anything to the matter. Feel free to do with
my suggested patch whatever You like -- I'm pretty sure You will do it quite
well as usial.

Reg's
Oleg

P.S. BTW, finally I had to give up with this PROXY idea coze in the
production environment ORACLE was somehow unhappy with a lot of connections
made by proxy-server. I guess we need a good approach which will allow us to
have proxy-server which is able to pool or to cash somehow
ORACLE-connections.



-----Original Message-----
From: Tim Bunce [mailto:Tim.Bunce@pobox.com]
Sent: Thursday, December 13, 2001 5:01 PM
To: Oleg Mechtcheriakov
Cc: 'Tim Bunce'; 'Scott T. Hildreth'; dbi-users@perl.org
Subject: Re: :Proxy and bind_param (with ORACLE)


FYI I've opted to apply the ProxyServer patch (thanks) but not the Proxy
patch for named bind params.  I'm not comfortable with the sql-editing
approach. Too risky for general use.

I think a better fix would be to treat $sth->{'proxy_params'} as a
list of lists of bind params, so a bind_param(1,$foo) would push
[1,$foo] onto teh list, and bind_param_inout(":baz",\$bar,10) would
push [":baz",\$bar,10] onto the list. The list-of-lists would be
easy to recognise and handle on the server side.

Tim.

On Thu, Aug 23, 2001 at 05:24:17PM +0200, Oleg Mechtcheriakov wrote:
> OK,
>
> here come 'diff -c' files.
>
> And sorry for not so good explanation. Clear English is not my best point.
> :-)
>
> But changes in the server and client code are independent. And basically
> only Proxy.pm has to be changed for sure. Changes in ProxyServer fix
another
> point.
>
> So I don't use hash ref to allow new clients to work with old server. That
> means that the communication and server's algorithm are kept the same.
>
> Reg's
> Oleg
>
>
>
> > -----Original Message-----
> > From: Tim Bunce [mailto:Tim.Bunce@pobox.com]
> > Sent: Thursday, August 23, 2001 5:04 PM
> > To: Oleg Mechtcheriakov
> > Cc: 'Scott T. Hildreth'; dbi-users@perl.org; 'Tim Bunce'
> > Subject: Re: :Proxy and bind_param (with ORACLE)
> >
> >
> > On Thu, Aug 23, 2001 at 03:57:18PM +0200, Oleg Mechtcheriakov wrote:
> > > OK,
> > >
> > > sorry for a delay, I was not in the office.
> > >
> > > The diff files are attached. The changes could be actually
> > too fast and
> > > dirty -- I'm just occasional programmer so may be I missed
> > some hidden magic
> > > behind of these modules.
> >
> > Why not just make params be a hash ref? Far simpler. (Don't
> > forget to allow
> > the server to handle both so old clients can still talk to a
> > newer server.)
> >
> > Tim.
> >
> > p.s. Please use a context diff format (diff -c or diff -u).
> >
> > > Here comes an explanation.
> > >
> > > ---- Proxy.pm. ----
> > > Existing version didn't handle named parameters in the
> > function bind_param
> > > (and bind_param_inout of course).
> > >
> > > The function is exented to handle named parameters as well.
> > Named parameters
> > > are supposed to be passed in the form
> > ':name_of_the_parameter'. The function
> > > replaces these named parameters in the quesry string with
> > ':p1', ':p2' and
> > > bind them as numbered parameters. This is allowed due to
> > the fact that
> > > DBD::Proxy doesn't make true 'prepare' and the query string
> > could be changed
> > > after 'prepare' was called.
> > >
> > > Perhaps the code itself has to be veryfied by some Perl
> > guru because I'm not
> > > 100% sure in my regular expressions. One more point is that
> > to make sure I
> > > programmed it so that named parameters in the form ':p1'
> > will be rejected
> > > but actually may be it was to restrictive.
> > >
> > > ---- ProxyServer.pm ----
> > > Existing version processed parameter binding in the
> > function 'execute' in a
> > > wrong way. The decision about which function to use, bind_param or
> > > bind_param_inout was made based on the number of the
> > parameters passed in
> > > the initial call of bind_param (or bind_param_inout) being
> > made on the
> > > client side (in the Proxy.pm). It worked well only when all
> > the parameters
> > > were given, i.e.
> > >
> > > $sth->bind_param_inout(1,\$addr_id,32,DBI::SQL_INTEGER)
> > >
> > > or
> > > $sth->bind_param(1,$addr_id,DBI::SQL_INTEGER)
> > >
> > >
> > > Actually my changes are optional and made mainly to get all
> > my existing
> > > scripts running whereas not all of them are supplying the
> > whole parameter
> > > list.
> > >
> > > Now the dicision which fucntion to use is made based on the
> > 'nature' of the
> > > parameter variable. It checks directly if this is a
> > reference or not.
> > >
> > > That's all. Your are welcom to ask for more detailed explanation.
> > >
> > > Reg's
> > > Oleg
> > >
> > >
> > >
> > >
> > >
> > > > -----Original Message-----
> > > > From: shildret@scotth.emsphone.com
> > > > [mailto:shildret@scotth.emsphone.com]On Behalf Of Scott
> > T. Hildreth
> > > > Sent: Tuesday, August 21, 2001 3:31 PM
> > > > To: Oleg Mechtcheriakov
> > > > Cc: dbi-users@perl.org
> > > > Subject: RE: :Proxy and bind_param (with ORACLE)
> > > >
> > > >
> > > >
> > > > I believe you want to send the patch to Tim, since DBD::Proxy is
> > > > bundled with DBI.
> > > >
> > > > On 21-Aug-01 Oleg Mechtcheriakov wrote:
> > > > > OK,
> > > > >
> > > > > now I'm ready to answer my question om my own.
> > > > >
> > > > > The point was exactly that. DBI::Proxy worked well only for
> > > > 'numbered'
> > > > > parameters. I've created small and dirty patch to work with
> > > > named parameters
> > > > > as well. Who is the right person to talk about the patch
> > > > for DBI::Proxy?
> > > > >
> > > > > Reg's
> > > > > Oleg
> > > > >
> > > > >> -----Original Message-----
> > > > >> From: Oleg Mechtcheriakov [mailto:ome@webcom.de]
> > > > >> Sent: Monday, August 20, 2001 12:35 PM
> > > > >> To: dbi-users@perl.org
> > > > >> Subject: DBD::Proxy and bind_param (with ORACLE)
> > > > >>
> > > > >>
> > > > >> Greetings,
> > > > >>
> > > > >> has someone experienced troubles with DBD::Proxy and
> > > > >> bind_param function?
> > > > >>
> > > > >> I'm trying to switch from DBD::Oracle to DBD::Proxy and
> > > > >> everything was OK
> > > > >> but bind_param gives me an exception.
> > > > >>
> > > > >> Here is the code snippet:
> > > > >>
> > > > >> my $addr_id;
> > > > >> my $sth = $dbh->prepare(q{BEGIN :id :=
> > > > >> first_req.check_req_sub_ok(:address);END;});
> > > > >> $sth->bind_param_inout(":id",\$addr_id,32,DBI::SQL_INTEGER);
> > > > >> $sth->bind_param(":address",$address);
> > > > >>
> > > > >> which gives me the following error message at the first
> > > > >> bind_param_inout
> > > > >>
> > > > >> Modification of non-creatable array value attempted,
> > > > subscript -1 at
> > > > >> /usr/local/lib/perl5/site_perl/5.6.1/i86pc-solaris/DBD/Proxy.p
> > > > >> m line 536
> > > > >>
> > > > >> Any ideas?
> > > > >>
> > > > >> Many thanks in advance
> > > > >> Oleg
> > > > >>
> > > > >>
> > > > >
> > > >
> > > > ----------------------------------
> > > > E-Mail: Scott T. Hildreth <shildreth@emsphone.com>
> > > > Date: 21-Aug-01
> > > > Time: 08:29:52
> > > > ----------------------------------
> > > >
> >
> >
> >
> >




From dbi-users-return-10603-Tim.Bunce=pobox.com@perl.org  Mon Apr  8 13:29:21 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g38CTLK33004
	for <timbo@localhost>; Mon, 8 Apr 2002 13:29:21 +0100 (BST)
	(envelope-from dbi-users-return-10603-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.58]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Mon, 08 Apr 2002 13:29:21 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1018257505:10:10894:53; Mon, 08 Apr 2002 09:18:25 GMT
Received: from dolly1.pobox.com ([207.106.49.22]) by punt-1.mail.demon.net
           id aa1011969; 8 Apr 2002 9:18 GMT
Received: from dolly1.pobox.com (localhost.localdomain [127.0.0.1])
	by dolly1.pobox.com (Postfix) with ESMTP id AD0BE2C0AD
	for <Tim.Bunce@data-plan.com>; Mon,  8 Apr 2002 05:17:56 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [209.85.157.220])
	by dolly1.pobox.com (Postfix) with SMTP id 38AEA2C0A5
	for <Tim.Bunce@pobox.com>; Mon,  8 Apr 2002 05:17:56 -0400 (EDT)
Received: (qmail 1684 invoked by uid 1005); 8 Apr 2002 09:17:52 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 1666 invoked by uid 76); 8 Apr 2002 09:17:51 -0000
Received: from patan.sun.com (HELO patan.sun.com) (192.18.98.43)
  by onion.perl.org (qpsmtpd/0.06) with SMTP; Mon Apr  8 09:17:51 2002 -0000
Received: from rannoch-mail1.UK.Sun.COM ([129.159.90.102])
	by patan.sun.com (8.9.3+Sun/8.9.3) with ESMTP id DAA16287
	for <dbi-users@perl.org>; Mon, 8 Apr 2002 03:17:48 -0600 (MDT)
Received: from sr-ellg01-03 (sr3-ge1-sf [129.159.90.208])
	by rannoch-mail1.UK.Sun.COM (8.10.2+Sun/8.10.2/ENSMAIL,v2.1p1) with SMTP id g389HlX09517
	for <dbi-users@perl.org>; Mon, 8 Apr 2002 10:17:48 +0100 (BST)
Message-Id: <200204080917.g389HlX09517@rannoch-mail1.UK.Sun.COM>
Date: Mon, 8 Apr 2002 10:17:47 +0100 (BST)
From: Ben Lowe - RMC EMEA - Web Developer <Ben.Lowe@Sun.COM>
Reply-To: Ben Lowe - RMC EMEA - Web Developer <Ben.Lowe@Sun.COM>
Subject: DBD::Proxy connecting to Oracle using PL/SQL and stored procedures
To: dbi-users@perl.org
MIME-Version: 1.0
Content-Type: TEXT/plain; charset=us-ascii
Content-MD5: IaPbbAlKo+8H8ojTXVpMsw==
X-Mailer: dtmail 1.3.0 @(#)CDE Version 1.4.2 SunOS 5.8 sun4u sparc 
Status: RO
X-Status: A
Content-Length: 2227
Lines: 70

Hi,

I have repeated my original post below. Does anyone on here know if it is 
possible to use inout parameters using DBD::Proxy ? Is this a specific problem
with oracle ? What I would like to do is to execute an oracle stored 
procedure and return back a primary key or an error message.Has anyone found a
way to do this if you can't use inout parameters ? 

cheers Ben
------------- Begin Forwarded Message -------------

Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Date: Fri, 5 Apr 2002 09:55:43 +0100 (BST)
From: Ben Lowe - RMC EMEA - Web Developer <Ben.Lowe@Sun.COM>
Subject: DBD::Proxy connecting to Oracle using PL/SQL and stored procedures
To: dbi-users@perl.org

Hello,

This is my first post to this list. I need to be able to run PL/SQL and
oracle stored procedures using the perl DBI. I am using the DBD::Proxy
driver to connect to the oracle server on another host. I cannot get
the following simple code to work.

my $p1;
my $csr = $dbh->prepare(q{
    begin
        :test := 1  * 2;
    end;
			 })or error(new CGI,$DBI::errstr);
  
$csr->bind_param_inout(':test', \$p1, 50) or error(new CGI,$DBI::errstr);
$csr->execute() or error(new CGI,$DBI::errstr);
print $p1;


Whenever I try to use placeholders I get the
following error:

 Argument ":test" isn't numeric in subtraction (-) at 
/usr/local/lib/perl5/site_perl/5.6.0/sun4-solaris/DBD/Proxy.pm line 536.
 
Is it not possible to get a return value using DBD::Proxy ? I have tried using ?
placeholders and this works for passing values to the statement but when
I try and get a value back nothing happens. Is this a limitation in DBD::Proxy ?

cheers Ben




------------- End Forwarded Message -------------


======================================================
Ben Lowe,                                ben.l@sun.com
 
Phone: +44 (0)1506 673425    5-digit shortdial: x73425
  
Web Developer		 EMEA Remote Monitoring Centre
  
LINLITHGOW,UK
======================================================



