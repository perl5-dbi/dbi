From perl5-porters-return-86361-Tim.Bunce=pobox.com@perl.org  Tue Dec 16 07:36:43 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id hBG7XIod085726
	for <timbo@localhost>; Tue, 16 Dec 2003 07:36:42 GMT
	(envelope-from perl5-porters-return-86361-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Tue, 16 Dec 2003 07:36:42 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1AW823-0002M7-FV;
	Tue, 16 Dec 2003 05:46:08 +0000
Received: from [207.8.214.3] (helo=puzzle.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1AW823-0002M7-FV
	for pobox@dbi.demon.co.uk; Tue, 16 Dec 2003 05:46:07 +0000
Received: from puzzle.pobox.com (localhost[127.0.0.1])
	by puzzle.pobox.com (Postfix) with ESMTP id 9BC4D16D79B
	for <pobox@dbi.demon.co.uk>; Tue, 16 Dec 2003 00:46:06 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost[127.0.0.1])
	by puzzle.pobox.com (Postfix) with ESMTP id 5115316CB8A
	for <Tim.Bunce@pobox.com>; Tue, 16 Dec 2003 00:46:06 -0500 (EST)
Received: from onion.perl.org (onion.develooper.com[63.251.223.166])
	by puzzle.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Tue, 16 Dec 2003 00:46:04 -0500 (EST)
Received: (qmail 33976 invoked by uid 1005); 16 Dec 2003 05:45:58 -0000
Mailing-List: contact perl5-porters-help@perl.org; run by ezmlm
Precedence: bulk
list-help: <mailto:perl5-porters-help@perl.org>
list-unsubscribe: <mailto:perl5-porters-unsubscribe@perl.org>
list-post: <mailto:perl5-porters@perl.org>
X-List-Archive: <http://nntp.perl.org/group/perl.perl5.porters/86361>
Delivered-To: mailing list perl5-porters@perl.org
Received: (qmail 33954 invoked by uid 76); 16 Dec 2003 05:45:58 -0000
Delivered-To: perl5-porters@perl.org
Message-ID: <3FDE9DCA.3050603@stason.org>
Date: Mon, 15 Dec 2003 21:53:14 -0800
From: Stas Bekman <stas@stason.org>
Organization: Hope, Humanized
User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.4) Gecko/20030630
X-Accept-Language: en-us, en, he, ru
MIME-Version: 1.0
To: The Perl5 Porters Mailing List <perl5-porters@perl.org>
Subject: regex memory leak introduced in 5.8.1
Content-Type: text/plain; charset=us-ascii; format=flowed
Content-Transfer-Encoding: 7bit
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=-3.2 required=7.0 tests=CARRIAGE_RETURNS,NOSPAM_INC,PERLBUG_CONF,SPAM_PHRASE_00_01,USER_AGENT,USER_AGENT_MOZILLA_UA,WEIRD_PORT,X_ACCEPT_LANG version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Status: RO
Content-Length: 7029
Lines: 262

I've spent a long time trying to find a bad memory leak in Apache::VMonitor. 
Finally I was successful at it. The memory leak is in Perl regex s///. It was 
introduced in 5.8.1 and exists in maint/blead perls. It doesn't exist in 5.6.2 
or 5.8.0.

Here is a simple script that reproduces the leak. If you don't have GTop, 
comment out the code related to it and uncomment the Devel::Leak code

use GTop ();
use Devel::Leak;

my $gtop = GTop->new;
my @attrs = qw(size vsize resident share rss);

my $url = 
'http://localhost:8529/vmonitor?pid=0&verbose=0&apache=0&apache_sort_by_ascend=0&refresh=0&system=0&procs=1&fs_usage=1&mount=1&apache_sort_by=size';

for (0..10) {
     warn "\n$_\n";

     my $before = $gtop->proc_mem($$);
     my %before = map { $_ => $before->$_() } @attrs;

     #my $handle;
     #my $count = Devel::Leak::NoteSV($handle);
     {
         my $x = fixup_url(refresh => 5);
         my $y = fixup_url(pid     => 123);
     }
     #Devel::Leak::CheckSV($handle);

     my $after = $gtop->proc_mem($$);
     my %after = map {$_ => $after->$_()} @attrs;
     warn sprintf "%-10s : %-5s\n", $_,
         GTop::size_string($after{$_} - $before{$_}),
               for sort @attrs;
}

sub fixup_url {
     my(%pairs) = @_;

     my $new_url = $url;
     while (my($k, $v) = each %pairs) {
         $new_url =~ s/$k=([^&]+)?/$k=$v/;
     }
}

Notice that the function fixup_url() doesn't return anything so it should 
dispose any temporaries at the end of its execution.

Here is what gtop reports:

0
resident   :    4k
rss        :    8k
share      :    4k
size       :    4k
vsize      :    0k

1
resident   :    0k
rss        :    0k
share      :    0k
size       :    0k
vsize      :    0k

2
resident   :    0k
rss        :    0k
share      :    0k
size       :    0k
vsize      :    0k

3
resident   :    4k
rss        :    4k
share      :    0k
size       :    4k
vsize      :    0k

4
resident   :    0k
rss        :    0k
share      :    0k
size       :    0k
vsize      :    0k

5
resident   :    4k
rss        :    4k
share      :    0k
size       :    4k
vsize      :    0k

6
resident   :    0k
rss        :    0k
share      :    0k
size       :    0k
vsize      :    0k

7
resident   :    4k
rss        :    4k
share      :    0k
size       :    4k
vsize      :    0k

8
resident   :    0k
rss        :    0k
share      :    0k
size       :    0k
vsize      :    0k

9
resident   :    4k
rss        :    4k
share      :    0k
size       :    4k
vsize      :    0k

10
resident   :    0k
rss        :    0k
share      :    0k
size       :    0k
vsize      :    0k

as you can see every few cycles more memory was consumed. If you comment out 
the regex, no memory leak occurs.

Here it Devel::Leak's report for one cycle:

new 0x80f8874 : SV = PVBM(0x80fb548) at 0x80f8874
   REFCNT = 1
   FLAGS = (SMG,POK,pPOK,VALID)
   UV = 0
   NV = 0
   PV = 0x80f9510 "pid="\0
   CUR = 4
   LEN = 262
   MAGIC = 0x80f9620
     MG_VIRTUAL = &PL_vtbl_bm
     MG_TYPE = PERL_MAGIC_bm(B)
new 0x80f8880 : SV = PVAV(0x80f916c) at 0x80f8880
   REFCNT = 1
   FLAGS = ()
   IV = 0
   NV = 0
   ARRAY = 0x80f8f90
   FILL = 2
   MAX = 3
   ARYLEN = 0x0
   FLAGS = (REAL)
new 0x805dd80 : SV = PV(0x80db420) at 0x805dd80
   REFCNT = 1
   FLAGS = (POK,pPOK)
   PV = 0x80f8db8 "# comment\12"\0
   CUR = 10
   LEN = 11
new 0x805ddc8 : SV = RV(0x808d9e8) at 0x805ddc8
   REFCNT = 1
   FLAGS = (ROK)
   RV = 0x805ddd4
new 0x805ddd4 : SV = PVAV(0x80e267c) at 0x805ddd4
   REFCNT = 1
   FLAGS = ()
   IV = 0
   NV = 0
   ARRAY = 0x80f8d28
   FILL = 2
   MAX = 3
   ARYLEN = 0x0
   FLAGS = (REAL)
new 0x805de58 : SV = PVBM(0x80fb520) at 0x805de58
   REFCNT = 1
   FLAGS = (SMG,POK,pPOK,VALID)
   UV = 0
   NV = 0
   PV = 0x80f8dc8 "refresh="\0
   CUR = 8
   LEN = 266
   MAGIC = 0x80f8ed8
     MG_VIRTUAL = &PL_vtbl_bm
     MG_TYPE = PERL_MAGIC_bm(B)
new 0x805dec4 : SV = PV(0x80db414) at 0x805dec4
   REFCNT = 1
   FLAGS = (POK,pPOK)
   PV = 0x80fd540 "# comment\12"\0
   CUR = 10
   LEN = 11
new 0x805df0c : SV = RV(0x808d9ec) at 0x805df0c
   REFCNT = 1
   FLAGS = (ROK)
   RV = 0x80f8880

----

Summary of my perl5 (revision 5.0 version 8 subversion 2) configuration:
   Platform:
     osname=linux, osvers=2.4.22-10mdk, archname=i686-linux-thread-multi
     uname='linux rabbit.stason.org 2.4.22-10mdk #1 thu sep 18 12:30:58 cest 
2003 i686 unknown unknown gnulinux '
     config_args='-des -Dprefix=/home/stas/perl/5.8.3-ithread -Dusethreads 
-Doptimize=-g -Duseshrplib -Dusedevel'
     hint=recommended, useposix=true, d_sigaction=define
     usethreads=define use5005threads=undef useithreads=define 
usemultiplicity=define
     useperlio=define d_sfio=undef uselargefiles=define usesocks=undef
     use64bitint=undef use64bitall=undef uselongdouble=undef
     usemymalloc=n, bincompat5005=undef
   Compiler:
     cc='cc', ccflags ='-D_REENTRANT -D_GNU_SOURCE -DTHREADS_HAVE_PIDS 
-DDEBUGGING -fno-strict-aliasing -I/usr/local/include -D_LARGEFILE_SOURCE 
-D_FILE_OFFSET_BITS=64 -I/usr/include/gdbm',
     optimize='-g',
     cppflags='-D_REENTRANT -D_GNU_SOURCE -DTHREADS_HAVE_PIDS -DDEBUGGING 
-fno-strict-aliasing -I/usr/local/include -I/usr/include/gdbm'
     ccversion='', gccversion='3.3.1 (Mandrake Linux 9.2 3.3.1-4mdk)', 
gccosandvers=''
     intsize=4, longsize=4, ptrsize=4, doublesize=8, byteorder=1234
     d_longlong=define, longlongsize=8, d_longdbl=define, longdblsize=12
     ivtype='long', ivsize=4, nvtype='double', nvsize=8, Off_t='off_t', 
lseeksize=8
     alignbytes=4, prototype=define
   Linker and Libraries:
     ld='cc', ldflags =' -L/usr/local/lib'
     libpth=/usr/local/lib /lib /usr/lib
     libs=-lnsl -lgdbm -ldb -ldl -lm -lcrypt -lutil -lpthread -lc
     perllibs=-lnsl -ldl -lm -lcrypt -lutil -lpthread -lc
     libc=/lib/libc-2.3.2.so, so=so, useshrplib=true, libperl=libperl.so
     gnulibc_version='2.3.2'
   Dynamic Linking:
     dlsrc=dl_dlopen.xs, dlext=so, d_dlsymun=undef, ccdlflags='-rdynamic 
-Wl,-rpath,/home/stas/perl/5.8.3-ithread/lib/5.8.2/i686-linux-thread-multi/CORE'
     cccdlflags='-fpic', lddlflags='-shared -L/usr/local/lib'


Characteristics of this binary (from libperl):
   Compile-time options: DEBUGGING MULTIPLICITY USE_ITHREADS USE_LARGE_FILES 
PERL_IMPLICIT_CONTEXT
   Locally applied patches:
         MAINT21829
   Built under linux
   Compiled at Dec 12 2003 08:08:24
   %ENV:
     PERLDOC_PAGER="less -R"
   @INC:
     /home/stas/perl/5.8.3-ithread/lib/5.8.2/i686-linux-thread-multi
     /home/stas/perl/5.8.3-ithread/lib/5.8.2
     /home/stas/perl/5.8.3-ithread/lib/site_perl/5.8.2/i686-linux-thread-multi
     /home/stas/perl/5.8.3-ithread/lib/site_perl/5.8.2
     /home/stas/perl/5.8.3-ithread/lib/site_perl
     .

__________________________________________________________________
Stas Bekman            JAm_pH ------> Just Another mod_perl Hacker
http://stason.org/     mod_perl Guide ---> http://perl.apache.org
mailto:stas@stason.org http://use.perl.org http://apacheweek.com
http://modperlbook.org http://apache.org   http://ticketmaster.com


