From lab@lincolnbaxter.com  Mon Jan 19 07:33:22 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i0J7XCFX065899
	for <timbo@localhost>; Mon, 19 Jan 2004 07:33:22 GMT
	(envelope-from lab@lincolnbaxter.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Mon, 19 Jan 2004 07:33:22 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1AiLds-00003F-9t;
	Sun, 18 Jan 2004 22:43:40 +0000
Received: from [208.210.124.70] (helo=majesty.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1AiLds-00003F-9t
	for pobox@dbi.demon.co.uk; Sun, 18 Jan 2004 22:43:40 +0000
Received: from majesty.pobox.com (localhost [127.0.0.1])
	by majesty.pobox.com (Postfix) with ESMTP id 7E15A15DB6
	for <pobox@dbi.demon.co.uk>; Sun, 18 Jan 2004 17:43:39 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by majesty.pobox.com (Postfix) with ESMTP id 583E615C01
	for <Tim.Bunce@pobox.com>; Sun, 18 Jan 2004 17:43:39 -0500 (EST)
Received: from sccrmhc12.comcast.net (sccrmhc12.comcast.net [204.127.202.56])
	by majesty.pobox.com (Postfix) with ESMTP
	for <Tim.Bunce@pobox.com>; Sun, 18 Jan 2004 17:43:38 -0500 (EST)
Received: from lincolnbaxter.com ([68.81.58.8])
          by comcast.net (sccrmhc12) with SMTP
          id <20040118224337012004pcque>; Sun, 18 Jan 2004 22:43:37 +0000
Received: (qmail 5406 invoked from network); 18 Jan 2004 17:43:36 -0500
Received: from lws (192.168.0.25)
  by lws with SMTP; 18 Jan 2004 17:43:36 -0500
Subject: Here you go....
From: "Lincoln A. Baxter" <lab@lincolnbaxter.com>
To: Tim Bunce <Tim.Bunce@pobox.com>
Cc: hirschs@btv.ibm.com
Content-Type: multipart/mixed; boundary="=-yA8PSRvvQ4b0TKs1Qspf"
Message-Id: <1074465816.5065.11.camel@lws>
Mime-Version: 1.0
X-Mailer: Ximian Evolution 1.4.5 
Date: Sun, 18 Jan 2004 17:43:36 -0500
Status: RO
Content-Length: 13237
Lines: 393


--=-yA8PSRvvQ4b0TKs1Qspf
Content-Type: text/plain
Content-Transfer-Encoding: 7bit

Hi Time,

Here is a a combined POD and test script. (The test script is extracted
from the POD and executed if you execute this file.)
 
With minor changes to this, you could even put it in the DBD-Oracle/t
directory.  (you'd have to skip it if Sys::SigAction could not be
loaded.

Let me know if this is what you were looking for.  

I wonder of O'Reilly & Assoc  might want to use this as one of their
perl email articles they send out periodically?

I was thinking of posting this to dbi-users.  What do you think?

Lincoln


--=-yA8PSRvvQ4b0TKs1Qspf
Content-Disposition: attachment; filename=dbd-oracle-timeout.t
Content-Type: text/x-troff; name=dbd-oracle-timeout.t; charset=UTF-8
Content-Transfer-Encoding: 7bit

#!/usr/bin/env perl
use strict;
use warnings;
use English;
undef $RS;
my $script = <DATA>;
$script =~ s,.*#!/usr/bin/env perl\s*,,gs;
$script =~ s/#end of test script.*//gs;
eval $script;
exit;

__END__

__DATA__


=head1 NAME

dbd-oracle-timeout.t - test timing out DBD-Oracle operations with Sys::SigAction

=head1 DESCRIPTION

Whenever one implements a real-time service that requires
responsiveness, and well behaved resource utilization, it is
imperative, that no operation take a long period of time.  Generally,
in these types of services,  timing out or failing and returning an 
error is preferable to hanging for long periods of time and potentially
bringing down an entire service because some resource the service uses
is not available.

We have implemented a number of real time services using perl
and the DBI interface using the DBD-Oracle driver.  This article
is specific to the problems encountered with Oracle, but the
author believes that the problem he encountered on moving from
perl 5.6 to perl 5.8, is a generic problem the could affect
any database driver that implementes restartable system calls
like connect().  The techniques presented here can be used 
to solve this kind of problem with any DBD driver, or for 
any system resource that could hang, for which
alarms have been used to break out of the call.

Prior to Perl 5.8.0, it as been fairly easy to use standard perl
signal handlers by setting code references into C<$SIG{'ALRM'}>
to timeout certain DBI operations.  The two operations, that
this author has need to time out are:

=over

=item 1 Database Host is Down -- connect() hangs

With SQL*Net, the DBI->connect() call will hang for about 4 minutes.
Traditionally this has been solved by using a localized signal
handler as follows:

   eval {
      local $SIG{ALRM} = sub { die "open timed out"; };
      alarm(2); #implement 2 second timeout
      $dbh = DBI->connect("dbi:Oracle:$dbn" ... );
      alarm(0);
   };
   alarm(0);
   if ( $@ ) { print "connection to $dbn timed out\n" ; }

This code restores the original C<$SIG{ALRM}> handler when the 
eval block is exited.

=item 2 Long Running Statements

Long running statements can occur for a variety of reasons out
side the control of the script.  These are timed out, to avoid
stacking of resources on the server on which the perl script is
executing.  This has been handled in a way similar to the that 
above:

   eval {
      local $SIG{ALRM} = sub { $sth->cancel(); };
      alarm(2); #implement 2 second timeout
      $sth->execute( ... );
      alarm(0);
   };
   alarm(0);
   if ( $@ ) { print "execute timed out\n" }

Again, the original C<$SIG{ALRM}> handler is retored when the 
eval block is exited.

=back

=head2 The Problem

Many of us have been using perl 5.6.x for several years now, and the above
code has worked just fine.  We understood that with perl 5.6 and prior signal
handling was 'unsafe', and we accepted the risk that the signal handler
could be called at an in-opportune time, causing non-reentrant system
routines to fail, leading to a perl core dump. For real-time services
this is considered an acceptable risk since failing quickly is preferable
to hanging around without returning.  Most programmers facing this
this problem, simply build mechanisms to restart things should a
catastrophic failure (perl core dump) occur.

As one moves to perl 5.8 or higher however, one will notice
that the above code (especially the connect code) no longer works.  
Instead, it just hangs. This is because with version 5.8, perl has been been
changing the way unix signals are implemented in an attempt to make
them safer.  Changes were made between perl 5.6 and perl 5.8,
and more changes have been made in versions of perl newer than 5.8.  

>From the perl 5.8.2 perlvar man page:

   The default delivery policy of signals changed in Perl 5.8.0 
   from immediate (also known as "unsafe") to deferred, also 
   known as "safe signals".  

Unfortunately this 'safe signals' approach causes some system calls to
be retried prior to the signal handler being called (depending on how
the code making the system call is implemented).  The result is
that it might never return. This is the case with the DBD-Oracle
connect call (case 1 above).  So the 'standard' mechanism for 
implementing timeouts (above) no longer works.

=head2 The Solution

The workaround (documented in the perlvar man page) is to use
POSIX::sigaction() which provides low level access to the POSIX 
sigaction() system API, to install the signal handler. This (of course)
assumes your system has sigaction(). If your system does not have 
sigaction, then you do not have the problem, as perl in this case
only implements the original (unsafe) signal handling approach.
With POSIX::sigaction(), one gets control over both the signal mask,
and the flags that are used to install the handler, and further, with
perl 5.8.2 and later, a 'safe' switch is provided which can be used
to ask for 'safe' signal handling, in which perl promises to call the
signal handler between perl op codes.

Using POSIX::sigaction() does ensure that the signal handler is called
when the signal is fired.  And if one calls die within the signal handler,
the call will be interupted, and control will return to the perl script.
The usage of POSIX::sigaction() however is not well documented (except for
several examples in the posix.t test in the perl core).  And in perls <
5.8.0, while POSIX::sigaction is defined, it does not seem to work.  But,
thats OK because just setting C<$SIG{NAME} does work.

=head2 The Pain

The down side of using POSIX::sigaction() (besides the fact that it does
not work in perls < 5.8) is that it requires approximately 4 or 5 lines
of code where previously one only had to set a localized C<$SIG{ALRM}>.

It looks something like this:

   use POSIX ':signal_h';

   my $mask = POSIX::SigSet->new( SIGALRM ); #list signals to mask in handler
   my $action = POSIX::SigAction->new( 
       sub { die "connect failed" ; } #the handler code ref
      ,$mask ); #assumes were not using an specific flags or 'safe' switch
   my $oldaction = POSIX::SigAction->new();
   sigaction( 'ALRM' ,$action ,$oldaction );
   eval {
      alarm(2); #implement 2 second timeout
      $dbh = DBI->connect("dbi:Oracle:$dbn" ... );
      alarm(0);
   };
   alarm(0);
   if ( $@ ) ....
   sigaction( 'ALRM' ,$oldaction ); #restore original signal handler

Needless to say, this is not a fun replacement for what was 
a single line of code in perl 5.6.x and before.  And now we have to
make it conditional on the perl version.

=head2 The Pain Releiver (Sys::SigAction)

Fortunately, having been bitten by this problem, and not wishing to 
have to replicate all the code every where, Lincoln Baxter 
(lab@lincolnbaxter.com) has implemented a module that makes using
POSIX::sigaction() as easy as setting C<$SIG{ALRM}> was in perl 5.6.x
and earlier versions.  This module can be retrieved from from CPAN: 

   http://search.cpan.org/CPAN/authors/LBAXTER

The Sys::SigAction module wraps up all of the above POSIX:: code into a single
function call which returns an object reference, that resets the signal handler 
when it goes out of scope.  So the above code becomes:

   use Sys::SigAction qw( set_sig_handler );
   eval {
      my $h = set_sig_handler( 'ALRM' ,sub { die "connect failed" ; } );
      alarm(2); #implement 2 second timeout
      $dbh = DBI->connect("dbi:Oracle:$dbn" ... );
      alarm(0);
   }; #original sighandler restored here when $h goes out of scope
   alarm(0);
   if ( $@ ) ....

And the nice thing about Sys::SigAction, is that it has been implemented
in a way works with older perls back to perl 5.005.  So, while
POSIX::sigaction() is not fully functional in perl versions less than 5.8,
Sys::SigAction can be used with to facilitate migration to newer perls, while
still supporting the older perls.  Thus, there is no need to write code 
conditioned on the perl version.

=head2 Sample Script 

The following test script illustrates the use of Sys::SigAction, with
the DBI interface (DBD-Oracle driver) to implement timeout of both connects
to databases on hosts that are down, and log running sql statements.

   #!/usr/bin/env perl
   use 5.006;
   use strict;
   use warnings;
   use Test::More tests => 10;
   use Data::Dumper;
   BEGIN { 
      use_ok('Sys::SigAction');
      use_ok('DBI');
   };
   use POSIX ':signal_h' ;
   use Cwd;


   die "please export ORACLE_USERID=<validuser>/<passwd>@<database>\n" 
         if not defined $ENV{'ORACLE_USERID'};

   my $last_octet = 256;
   my $got_down_host = 0;
   my $down_host ;
   do {
      $last_octet--;
      $down_host = "10.255.255.$last_octet";
   } until $got_down_host = system( "ping -c 1 -t 1 $down_host 2>&1 > /dev/null" )
     or $last_octet == 0;

   ok( $got_down_host ,"Found IP addr ($down_host) for missing system test\n" );

   #parse ORACLE_USERID
   my $dbn='';
   my $usr='';
   my $pwd='';

   ( $usr ,$pwd ,$dbn ) = split( /[\/\@]/ ,$ENV{'ORACLE_USERID'} );
   ok( $usr ,"database user: '$usr' defined" );
   ok( $pwd ,"password for $usr is defined" );
   ok( $dbn ,"database name: '$dbn' defined" );

   #I'm lazy... this stuff is unix specific...
   #but then if you are using SigAction that is pretty unix
   #specific too!
   #
   #need a locally writeable tns_admin directory
   #so we copy it from $TNS_ADMIN and then redefine
   #TNS_ADMIN to the local copy
   my $save_TNS_ADMIN = $ENV{'TNS_ADMIN'};
   die if not ok( $save_TNS_ADMIN ,'$TNS_ADMIN is defined' );
   my $tmp_tns = cwd() . '/tmp_tns_admin' ;
   system( "rm -rf $tmp_tns" ) if -d $tmp_tns;
   mkdir $tmp_tns;
   system( "cp $save_TNS_ADMIN/*.* $tmp_tns/" );

   open( TNSNAMES ,">>$tmp_tns/tnsnames.ora" ) 
      or die "could not open $tmp_tns/tnsnames.org: $!\n" ;
   my $testdbfail = qq(testdbfail =
     (DESCRIPTION =
       (ADDRESS_LIST =
         (ADDRESS = (PROTOCOL = TCP)(HOST = $down_host)(PORT = 1521))
       )
       (CONNECT_DATA =
         (SERVICE_NAME = testdbfail)
       )
     )
   );
   #ok... we have a local TNS_ADMIN directory with testdbfile
   $ENV{TNS_ADMIN} = $tmp_tns;
   print "redefining TNS_ADMIN=$tmp_tns\n" ;
   print "appending to $tmp_tns/tnsnames.ora:\n$testdbfail\n" ;
   print TNSNAMES $testdbfail;
   close TNSNAMES;


   #now get set_sig_handler function from Sys::SigAction
   use Sys::SigAction qw( set_sig_handler );

   my $dbh;
   print "trying missing host\n" ;
   eval {
      my $code = sub {
            die "timed out on connect to database on missing host\n" ;
      };
      my $h = set_sig_handler( 'ALRM' ,$code ,0 ,1 );
      alarm(2);
      print "opening testdbfail (missing host test)\n" ;
      $dbh = DBI->connect("dbi:Oracle:testdbfail" ,"na" ,"na" );
      alarm(0);
      print "connect failed!\n" if not $dbh;
      ok( 0 ,"after missing_host connect... how did we get here?\n" );
   };
   alarm(0);
   if ( $@ )
   {
      ok( 1 ,"exception: $@" );
   }
   print "after missing_host test\n" ;


   print "connecting to $dbn as $usr\n" ;
   $dbh = DBI->connect(
         "dbi:Oracle:$dbn" ,$usr ,$pwd 
        ,{ RaiseError=>1 ,AutoCommit=>0 ,PrintError => 0 } );

   ok( $dbh ,"connected" );

   my $sql = qq{
      BEGIN
         WHILE ( 1 > 0 ) LOOP
            NULL;
         END LOOP;
      END; 
   };

   print "preparing:\n$sql" ;
   my $sth = $dbh->prepare( $sql );
   my $canceled = 0;
   eval {
      my $h = set_sig_handler( 'ALRM' 
                              ,sub { $canceled = 1; 
                                     $sth->cancel(); 
                                     #dont die (oracle spills its guts)
                                     }
                              ,{ mask=>[ qw( INT ALRM ) ] ,safe => 1 } 
                              );
      my $timeout =3;
      print "\ncalling execute with $timeout second timeout\n" ;
      alarm($timeout);
      $sth->execute();
      alarm(0);
      ok( 0 ,"after execute of infinite statement (how did we get here?)\n" );
   };
   alarm(0);
   if ( $@ )
   {
      print $@ if not $@ =~ m/DBD::Oracle/;
      ok( $canceled ,'infinite statement timed out' );
      $dbh->rollback();
      $dbh->disconnect();
      exit;
   }
   die 'how we we get here' ;

   #end of test script

=head1 AUTHOR

   Lincoln A Baxter E<lt>lab@lincolnbaxter.comE<gt>

=head1 SEE ALSO

   perldoc perlvar 
   perldoc POSIX



--=-yA8PSRvvQ4b0TKs1Qspf--


From timbo@dansat.data-plan.com  Mon Jan 19 18:33:01 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i0JIUqGT075032
	for <timbo@localhost>; Mon, 19 Jan 2004 18:33:01 GMT
	(envelope-from timbo@dansat.data-plan.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Mon, 19 Jan 2004 18:33:01 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1AidsW-00001o-Nd;
	Mon, 19 Jan 2004 18:12:01 +0000
Received: from [208.210.124.70] (helo=majesty.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1AidsW-00001o-Nd
	for pobox@dbi.demon.co.uk; Mon, 19 Jan 2004 18:12:00 +0000
Received: from majesty.pobox.com (localhost [127.0.0.1])
	by majesty.pobox.com (Postfix) with ESMTP id 3FF1517E7A
	for <pobox@dbi.demon.co.uk>; Mon, 19 Jan 2004 13:11:59 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by majesty.pobox.com (Postfix) with ESMTP id 03C1D17EC2
	for <Tim.Bunce@pobox.com>; Mon, 19 Jan 2004 13:11:59 -0500 (EST)
Received: from mail09.svc.cra.dublin.eircom.net (mail09.svc.cra.dublin.eircom.net [159.134.118.25])
	by majesty.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Mon, 19 Jan 2004 13:11:57 -0500 (EST)
Received: (qmail 9187 messnum 266690 invoked from network[213.94.228.233/unknown]); 19 Jan 2004 18:11:54 -0000
Received: from unknown (HELO dansat.data-plan.com) (213.94.228.233)
  by mail09.svc.cra.dublin.eircom.net (qp 9187) with SMTP; 19 Jan 2004 18:11:54 -0000
Received: from dansat.data-plan.com (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i0JIDjFO074805;
	Mon, 19 Jan 2004 18:13:45 GMT
	(envelope-from timbo@dansat.data-plan.com)
Received: (from timbo@localhost)
	by dansat.data-plan.com (8.12.9/8.12.9/Submit) id i0JIDhBQ074804;
	Mon, 19 Jan 2004 18:13:43 GMT
Date: Mon, 19 Jan 2004 18:13:43 +0000
From: Tim Bunce <Tim.Bunce@pobox.com>
To: "Lincoln A. Baxter" <lab@lincolnbaxter.com>
Cc: Tim Bunce <Tim.Bunce@pobox.com>, hirschs@btv.ibm.com
Subject: Re: Here you go....
Message-ID: <20040119181343.GA74780@dansat.data-plan.com>
References: <1074465816.5065.11.camel@lws>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <1074465816.5065.11.camel@lws>
User-Agent: Mutt/1.4i
Status: RO
Content-Length: 998
Lines: 33

It's good. Thanks!

I would suggest a few small changes. The main one is to not use the
third-person.  It should be you ("I") talking to a reader ("you").
It's much more direct and personal, and so more readable and memorable.

There are a few pod glitches so run it through pod2html to see those.

I'm sure perl.com would be interested in it as an article.

Tim.

On Sun, Jan 18, 2004 at 05:43:36PM -0500, Lincoln A. Baxter wrote:
> Hi Time,
> 
> Here is a a combined POD and test script. (The test script is extracted
> from the POD and executed if you execute this file.)
>  
> With minor changes to this, you could even put it in the DBD-Oracle/t
> directory.  (you'd have to skip it if Sys::SigAction could not be
> loaded.
> 
> Let me know if this is what you were looking for.  
> 
> I wonder of O'Reilly & Assoc  might want to use this as one of their
> perl email articles they send out periodically?
> 
> I was thinking of posting this to dbi-users.  What do you think?
> 
> Lincoln
> 



From lab@lincolnbaxter.com  Tue Jan 20 07:37:25 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i0K7Z6Gg081147
	for <timbo@localhost>; Tue, 20 Jan 2004 07:37:25 GMT
	(envelope-from lab@lincolnbaxter.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Tue, 20 Jan 2004 07:37:25 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1AiomY-00030m-Kk;
	Tue, 20 Jan 2004 05:50:34 +0000
Received: from [208.210.124.70] (helo=majesty.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1AiomY-00030m-Kk
	for pobox@dbi.demon.co.uk; Tue, 20 Jan 2004 05:50:34 +0000
Received: from majesty.pobox.com (localhost [127.0.0.1])
	by majesty.pobox.com (Postfix) with ESMTP id C042518FCC
	for <pobox@dbi.demon.co.uk>; Tue, 20 Jan 2004 00:50:33 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by majesty.pobox.com (Postfix) with ESMTP id 9545719012
	for <Tim.Bunce@pobox.com>; Tue, 20 Jan 2004 00:50:33 -0500 (EST)
Received: from rwcrmhc12.comcast.net (rwcrmhc12.comcast.net [216.148.227.85])
	by majesty.pobox.com (Postfix) with ESMTP
	for <Tim.Bunce@pobox.com>; Tue, 20 Jan 2004 00:50:32 -0500 (EST)
Received: from lincolnbaxter.com ([68.81.58.8])
          by comcast.net (rwcrmhc12) with SMTP
          id <20040120055032014004p6e3e>; Tue, 20 Jan 2004 05:50:32 +0000
Received: (qmail 25579 invoked from network); 20 Jan 2004 00:50:31 -0500
Received: from lws (192.168.0.25)
  by lws with SMTP; 20 Jan 2004 00:50:31 -0500
Subject: Re: Here you go....
From: "Lincoln A. Baxter" <lab@lincolnbaxter.com>
To: Tim Bunce <Tim.Bunce@pobox.com>
Cc: hirschs@btv.ibm.com
In-Reply-To: <20040119181343.GA74780@dansat.data-plan.com>
References: <1074465816.5065.11.camel@lws>
	 <20040119181343.GA74780@dansat.data-plan.com>
Content-Type: text/plain
Message-Id: <1074577830.5068.280.camel@lws>
Mime-Version: 1.0
X-Mailer: Ximian Evolution 1.4.5 
Date: Tue, 20 Jan 2004 00:50:30 -0500
Content-Transfer-Encoding: 7bit
Status: RO
Content-Length: 514
Lines: 19

On Mon, 2004-01-19 at 13:13, Tim Bunce wrote:
> [snip]

> I would suggest a few small changes. The main one is to not use the
> third-person.  It should be you ("I") talking to a reader ("you").
Thanks, thats helpful, I will rewrite.

> There are a few pod glitches so run it through pod2html to see those.
will do

> I'm sure perl.com would be interested in it as an article.
I sent at message to nuts@oreilly.com describing the article, and asking
if they are interested, to whom it should be sent.

Lincoln





From perl5-porters-return-87748-Tim.Bunce=pobox.com@perl.org  Sun Jan 25 12:35:30 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i0PCYRlA022887
	for <timbo@localhost>; Sun, 25 Jan 2004 12:35:30 GMT
	(envelope-from perl5-porters-return-87748-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Sun, 25 Jan 2004 12:35:30 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1AkhYO-0001u5-ED;
	Sun, 25 Jan 2004 10:31:44 +0000
Received: from [208.58.1.194] (helo=integer.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1AkhYO-0001u5-ED
	for pobox@dbi.demon.co.uk; Sun, 25 Jan 2004 10:31:44 +0000
Received: from integer.pobox.com (localhost [127.0.0.1])
	by integer.pobox.com (Postfix) with ESMTP id 4FF601E497
	for <pobox@dbi.demon.co.uk>; Sun, 25 Jan 2004 05:31:43 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by integer.pobox.com (Postfix) with ESMTP id 236991E491
	for <Tim.Bunce@pobox.com>; Sun, 25 Jan 2004 05:31:43 -0500 (EST)
Received: from onion.perl.org (onion.develooper.com [63.251.223.166])
	by integer.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Sun, 25 Jan 2004 05:31:42 -0500 (EST)
Received: (qmail 49921 invoked by uid 1005); 25 Jan 2004 10:31:40 -0000
Mailing-List: contact perl5-porters-help@perl.org; run by ezmlm
Precedence: bulk
list-help: <mailto:perl5-porters-help@perl.org>
list-unsubscribe: <mailto:perl5-porters-unsubscribe@perl.org>
list-post: <mailto:perl5-porters@perl.org>
X-List-Archive: <http://nntp.perl.org/group/perl.perl5.porters/87748>
Delivered-To: mailing list perl5-porters@perl.org
Delivered-To: moderator for perl5-porters@perl.org
Received: (qmail 30117 invoked by uid 76); 25 Jan 2004 00:24:10 -0000
Delivered-To: perl5-porters@perl.org
Date: Sun, 25 Jan 2004 11:23:48 +1100
From: "Brendan O'Dea" <bod@debian.org>
To: Perl5 Porters <perl5-porters@perl.org>
Cc: Britton Leo Kerin <fsblk@aurora.uaf.edu>, 224235@bugs.debian.org
Subject: [PATCH] 5.8.3 -- fix signal comments in L<perlfunc/system>
Message-ID: <20040125002348.GA31407@londo.c47.org>
Mail-Followup-To: Perl5 Porters <perl5-porters@perl.org>,
	Britton Leo Kerin <fsblk@aurora.uaf.edu>, 224235@bugs.debian.org
References: <E1AWWOA-00064m-00@greenwood>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <E1AWWOA-00064m-00@greenwood>
User-Agent: Mutt/1.5.5.1+cvs20040105i
X-Spam-Check-By: la.mx.develooper.com
X-Spam-Status: No, hits=-1.9 required=7.0 tests=CARRIAGE_RETURNS,IN_REP_TO,REFERENCES,SPAM_PHRASE_02_03,USER_AGENT,USER_AGENT_MUTT version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Status: RO
Content-Length: 2048
Lines: 51

On Tue, Dec 16, 2003 at 10:46:28PM -0900, Britton Leo Kerin wrote:
>In the output of perldoc -f system, I read this:
>...
>Because "system" and backticks block "SIGINT" and "SIGQUIT", killing
>the program they're running doesn't actually interrupt your program.
>...
>
>But in fact system() builtin IGNORES these signals during execution of
>the system() builtin, just like system(3).  They don't get handled
>after system() is done, as would happen if they were blocked and then
>unblocked on system() completion.  [...]

Quite correct.  Moreover it appears that backticks (also mentioned)
neither block or ignore these signals.

A patch for upstream is attached.

As an aside, I found a quite good explanation for why signals are
ignored in these* APPLICATION NOTES for system(3).  It is perhaps
interesting that the one situation described where this behaviour has
"less than the desired effect" is probably the most common in Perl.

* http://www.opengroup.org/onlinepubs/007904975/functions/system.html#tag_03_757_07

--bod

diff -Naur --exclude=debian perl-5.8.3.orig/pod/perlfunc.pod perl-5.8.3/pod/perlfunc.pod
--- perl-5.8.3.orig/pod/perlfunc.pod	2004-01-14 08:51:09.000000000 +1100
+++ x/perl-5.8.3/pod/perlfunc.pod	2004-01-25 10:13:18.000000000 +1100
@@ -5761,9 +5761,10 @@
 Like C<exec>, C<system> allows you to lie to a program about its name if
 you use the C<system PROGRAM LIST> syntax.  Again, see L</exec>.
 
-Because C<system> and backticks block C<SIGINT> and C<SIGQUIT>,
-killing the program they're running doesn't actually interrupt
-your program.
+Since C<SIGINT> and C<SIGQUIT> are ignored during the execution of
+C<system>, if you expect your program to terminate on receipt of these
+signals you will need to arrange to do so yourself based on the return
+value.
 
     @args = ("command", "arg1", "arg2");
     system(@args) == 0
@@ -5783,7 +5784,6 @@
 	printf "child exited with value %d\n", $? >> 8;
     }
 
-
 or more portably by using the W*() calls of the POSIX extension;
 see L<perlport> for more information.
 

