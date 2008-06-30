From dbi-users-return-8931-Tim.Bunce=pobox.com@perl.org  Tue Jan 29 16:20:44 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g0TGKhU62145
	for <timbo@localhost>; Tue, 29 Jan 2002 16:20:43 GMT
	(envelope-from dbi-users-return-8931-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.40]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Tue, 29 Jan 2002 16:20:43 +0000 (GMT)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1012320821:11:23499:26; Tue, 29 Jan 2002 16:13:41 GMT
Received: from wormwood.pobox.com ([208.210.125.20]) by punt-1.mail.demon.net
           id aa1102528; 29 Jan 2002 16:00 GMT
Received: from wormwood.pobox.com (localhost.pobox.com [127.0.0.1])
	by wormwood.pobox.com (Postfix) with ESMTP id C24C87255B
	for <Tim.Bunce@data-plan.com>; Tue, 29 Jan 2002 10:59:28 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [209.85.157.220])
	by wormwood.pobox.com (Postfix) with SMTP id E31467251C
	for <Tim.Bunce@pobox.com>; Tue, 29 Jan 2002 10:59:27 -0500 (EST)
Received: (qmail 48658 invoked by uid 1005); 29 Jan 2002 15:56:53 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 48478 invoked by uid 76); 29 Jan 2002 15:56:48 -0000
Received: from gw.peppler.org (HELO kiruna.peppler.org) (206.55.243.57)
  by onion.perl.org (qpsmtpd/0.06) with SMTP; Tue Jan 29 15:56:48 2002 -0000
Received: from troll.peppler.org (troll [192.168.0.4])
	by kiruna.peppler.org (8.9.1b+Sun/8.9.1) with ESMTP id HAA13392;
	Tue, 29 Jan 2002 07:56:37 -0800 (PST)
Received: (from mpeppler@localhost)
	by troll.peppler.org (8.11.6/8.11.6) id g0TFuaG16479;
	Tue, 29 Jan 2002 07:56:36 -0800
From: Michael Peppler <mpeppler@peppler.org>
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: 7bit
Message-ID: <15446.50740.489133.566962@troll.peppler.org>
Date: Tue, 29 Jan 2002 07:56:36 -0800
To: "Abi Pothen" <apothen@hotmail.com>
Cc: dbi-users@perl.org, dgood@stratasource.com, Tim.Bunce@ig.co.uk
Subject: Re: Multiple Results in DBD::ODBC 0.31
In-Reply-To: <LAW2-F38LqN33HFnwpG000044d7@hotmail.com>
References: <LAW2-F38LqN33HFnwpG000044d7@hotmail.com>
X-Mailer: VM 6.92 under 21.1 (patch 12) "Channel Islands" XEmacs Lucid
Status: RO
X-Status: A
Content-Length: 2355
Lines: 76

[ redirected to dbi-users ]

Abi Pothen writes:
 > Hi,
 >   I am having a problem with DBD::ODBC (version 0.31) that has fixes to 
 > handle multiple result set. This fix is working fine only when the number of 
 > columns of the previous result set is equal to or greater than the number of 
 > columns of the following result set. If the number of columns of the result 
 > set of the previous result set is greater than the following, SQLFetch 
 > function call is failing and returning -1.

I've had to handle that in DBD::Sybase (as well as clearing the
NAME_xx attribute cache between result sets).

I'm not sure that I've got the best solution, but I have code like
this in dbdimp.c between result sets:

    av = DBIS->get_fbav(imp_sth);
    num_fields = AvFILL(av)+1;

    /* XXX
       The code in the if() below is likely to break with new versions
       of DBI!!! */
    if(num_fields < imp_sth->numCols) {
	int isReadonly = SvREADONLY(av);
	if(isReadonly)
	    SvREADONLY_off(av);		/* DBI sets this readonly  */
	i = imp_sth->numCols - 1;
	while(i >= num_fields)
	    av_store(av, i--, newSV(0));
	num_fields = AvFILL(av)+1;
	if(isReadonly)
	    SvREADONLY_on(av);		/* protect against shift @$row etc */
    } else if(num_fields > imp_sth->numCols) {
	int isReadonly = SvREADONLY(av);
	if(isReadonly)
	    SvREADONLY_off(av);		/* DBI sets this readonly  */
	av_fill(av, imp_sth->numCols - 1);
	num_fields = AvFILL(av)+1;
	if(isReadonly)
	    SvREADONLY_on(av);		/* protect against shift @$row etc */
    }

and

	      if(imp_sth->done_desc) {
		  HV *hv = (HV*)SvRV(sth);
		  HE *he;

		  cleanUp(imp_sth);
		  
		  hv_iterinit(hv);
		  while((he = hv_iternext(hv))) {
		      I32 i;
		      char *key = hv_iterkey(he, &i);
		      SV *sv = hv_iterval(hv, he);

		      if(strnEQ(key, "NAME", 4)) {
			  if(dbis->debug >= 3)
			      PerlIO_printf(DBILOGFP, 
			       "    st_next_result() -> delete key %s (%s) from cache\n",
					    key, neatsvpv(sv, 0));

			  hv_delete(hv, key, i, G_DISCARD);
		      }
		  }
	      }

I'm not really sure that this last bit is all that is needed, or the
correct way to clear the cached attributes, but it seems to work.

Michael
-- 
Michael Peppler - Data Migrations Inc. - http://www.mbay.net/~mpeppler
mpeppler@peppler.org - mpeppler@mbay.net
International Sybase User Group - http://www.isug.com

