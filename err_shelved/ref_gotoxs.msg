From timbo  Tue Nov 30 00:26:25 1999
Return-Path: <timbo>
Received: by toad.ig.co.uk (SMI-8.6/SMI-SVR4)
	id AAA17404; Tue, 30 Nov 1999 00:26:25 GMT
Date: Tue, 30 Nov 1999 00:26:25 +0000
From: Tim Bunce <timbo@ig.co.uk>
To: Tim Bunce <timbo@ig.co.uk>
Subject: driver calling goto kills application!
Message-ID: <19991130002625.B17204@ig.co.uk>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
X-Mailer: Mutt 0.95.3i
Content-Length: 139
Lines: 9

Adding this code:

	my $foo=0;
	LOOP:
	warn "LOOP";
	goto LOOP unless ++$foo >= 2;

causes the DBI to die when the driver method returns.


