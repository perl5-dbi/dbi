From michael.schaefer@dlr.de  Thu Jan 21 12:04:20 1999
Return-Path: <michael.schaefer@dlr.de>
Received: from oink by toad.ig.co.uk (SMI-8.6/SMI-SVR4)
	id MAA07309; Thu, 21 Jan 1999 12:04:17 GMT
Received: from punt-21.mail.demon.net by oink with SMTP (PP) id <09006-28@oink>;
          Thu, 21 Jan 1999 12:02:31 +0000
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@ig.co.uk 
          id 916863427:20:14755:13; Wed, 20 Jan 99 20:17:07 GMT
Received: from ttyc1.braunschweig.netsurf.de ([194.195.236.131]) 
          by punt-2.mail.demon.net id aa2014522; 20 Jan 99 20:16 GMT
Received: from mica (helo=localhost) by shadowlands.darknet 
          with local-smtp (Exim 2.03 #4) id 103450-0000cw-00 
          for Tim.Bunce@ig.co.uk; Wed, 20 Jan 1999 21:18:22 +0100
Date: Wed, 20 Jan 1999 21:18:22 +0100 (CET)
From: Michael Schaefer <michael.schaefer@dlr.de>
To: Tim.Bunce@ig.co.uk
Subject: DBI promlem?
Message-ID: <Pine.LNX.4.02.9901202113240.2404-200000@shadowlands.darknet>
MIME-Version: 1.0
Content-Type: MULTIPART/MIXED; BOUNDARY="-1463786751-2140409513-916863502=:2404"
Status: RO
Content-Length: 2582
Lines: 57

  This message is in MIME format.  The first part should be readable text,
  while the remaining parts are likely unreadable without MIME-aware tools.
  Send mail to mime@docserver.cac.washington.edu for more info.

---1463786751-2140409513-916863502=:2404
Content-Type: TEXT/PLAIN; charset=US-ASCII

Hi,

I have sorta serious problem using DBI 1.06 (DBD:mysql 1.2015) together
with Perl/TK (800.012). I attached a sample code demonstrating the
problem.

I use bind_col to bind a column to a variable. The variable gets updated,
that part works fine. But it seems to get updated in a manner Perl/TK
Widgets are not notified about the change (Entry widget which is bound to
the variable too). Updating a variable given by reference inside perl
(function test in demo.pl) works fine. 

I am not sure if it is a problem of DBI, DBD:mysql or Perl/TK .), but
maybe you can help me.

The Perl version I am using is 5.002_02 with Linux 2.2-pre7 (Don't think
it is a linux problem which is the reason I did not try with stable
kernels)

Michael

---1463786751-2140409513-916863502=:2404
Content-Type: TEXT/PLAIN; charset=US-ASCII; name="demo.pl"
Content-Transfer-Encoding: BASE64
Content-ID: <Pine.LNX.4.02.9901202118220.2404@shadowlands.darknet>
Content-Description: 
Content-Disposition: attachment; filename="demo.pl"

IyEvdXNyL2Jpbi9wZXJsIC13DQoNCnVzZSBzdHJpY3Q7DQp1c2UgREJJOw0K
dXNlIFRrOw0KDQpteSAkbmFtZTsNCg0KIyBUaGlzIGZ1bmN0aW9uIHVwZGF0
ZXMgJG5hbWUsIGJ1dCB0aGUgJEVudHJ5IHdpZGdldCBkb2VzIG5vdCBub3Rp
ZnkgaXQNCnN1YiBmZXRjaF9lbnRyeSB7DQoJbXkgKCAkaWQgKSA9IEBfOw0K
ICAgIG15KCAkZGJoLCAkc3RoICk7DQoNCglwcmludCAiJG5hbWVcbiI7ICMg
aXN0IGhpZXIgInRlc3QiOw0KCQ0KICAgICRkYmggPSBEQkktPmNvbm5lY3Qo
ICJEQkk6bXlzcWw6ZGF0YWJhc2U9ZmlybWVuIiwgInJvb3QiLCB1bmRlZiAp
Ow0KDQogICAgJHN0aCA9ICRkYmgtPnByZXBhcmUoIlNFTEVDVCBmaXJtZW5u
YW1lIEZST00gZmlybWVuIFdIRVJFIGZpcm1lbmlkID0gPyAiKTsNCiAgICAk
c3RoLT5leGVjdXRlKCAkaWQgKTsNCgkkc3RoLT5iaW5kX2NvbCggMSwgXCRu
YW1lICk7DQojCSRzdGgtPmJpbmRfY29sdW1ucyggdW5kZWYsIFwkbmFtZSAp
Ow0KCSRzdGgtPmZldGNoOw0KCQ0KICAgICRzdGgtPmZpbmlzaDsNCiAgICAk
ZGJoLT5kaXNjb25uZWN0Ow0KDQoJcHJpbnQgIiRuYW1lXG4iOyAjIGlzdCBo
aWVyIG5pY2h0IG1laHIgdGVzdCwgbnVyIGRhcyB3aWRnZXQgJGVudHJ5IGth
cGllcnQgZXMgbmljaHQNCg0KfQ0KDQojIFRoaXMgZnVuY3Rpb24gd29ya3MN
CnN1YiB0ZXN0IHsNCglteSAoICRuYW1lcmVmICkgPSBAXzsNCgkNCgkkJG5h
bWVyZWYgPSAidGVzdCI7DQp9DQoNCg0KbXkgJG1haW4gPSBuZXcgVGs6Ok1h
aW5XaW5kb3c7DQpteSAkZW50cnkgPSAkbWFpbi0+RW50cnkoIC13aWR0aD0+
NDAsIC10ZXh0dmFyaWFibGU9PiBcJG5hbWUpLT5wYWNrOw0KDQomdGVzdCgg
XCRuYW1lICk7DQomZmV0Y2hfZW50cnkoIDEgKTsNCg0KVGs6Ok1haW5Mb29w
Ow0K
---1463786751-2140409513-916863502=:2404--

