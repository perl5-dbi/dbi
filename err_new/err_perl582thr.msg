From dbi-users-return-21278-Tim.Bunce=pobox.com@perl.org  Sun Dec 14 18:36:38 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id hBEIYonJ069761
	for <timbo@localhost>; Sun, 14 Dec 2003 18:36:34 GMT
	(envelope-from dbi-users-return-21278-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Sun, 14 Dec 2003 18:36:34 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1AVU2p-0000h6-C8;
	Sun, 14 Dec 2003 11:04:16 +0000
Received: from [208.58.1.194] (helo=integer.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1AVU2p-0000h6-C8
	for pobox@dbi.demon.co.uk; Sun, 14 Dec 2003 11:04:15 +0000
Received: from integer.pobox.com (localhost[127.0.0.1])
	by integer.pobox.com (Postfix) with ESMTP id 526B71DE85B
	for <pobox@dbi.demon.co.uk>; Sun, 14 Dec 2003 06:04:14 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost[127.0.0.1])
	by integer.pobox.com (Postfix) with ESMTP id 3B7F81DE80B
	for <Tim.Bunce@pobox.com>; Sun, 14 Dec 2003 06:04:14 -0500 (EST)
Received: from onion.perl.org (onion.develooper.com[63.251.223.166])
	by integer.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Sun, 14 Dec 2003 06:04:13 -0500 (EST)
Received: (qmail 6821 invoked by uid 1005); 14 Dec 2003 11:04:12 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Delivered-To: moderator for dbi-users@perl.org
Received: (qmail 87244 invoked by uid 76); 14 Dec 2003 05:34:32 -0000
Delivered-To: dbi-users@perl.org
X-Authentication-Warning: andyt.mypoints.com: andyt owned process doing -bs
Date: Sat, 13 Dec 2003 23:33:48 -0600 (CST)
From: Andy Tsouladze <andyt@ualloyalty.com>
X-X-Sender: andyt@andyt.mypoints.com
To: dbi-users@perl.org
Cc: Tim.Bunce@ig.co.uk
Subject: DBI would not compile
Message-ID: <Pine.LNX.4.58.0312132308580.9335@andyt.mypoints.com>
Importance: normal
MIME-Version: 1.0
Content-Type: TEXT/PLAIN; charset=US-ASCII
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=-3.7 required=7.0 tests=CARRIAGE_RETURNS,PERLBUG_CONF,SPAM_PHRASE_00_01,USER_AGENT_PINE,X_AUTH_WARNING version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Content-Length: 9200
Lines: 222

Hello,

As part of a general upgrade, I am trying to compile DBI-1.39 module. Here
is what I have:

Sparc Solaris 8 64-bit

GCC: 3.3.2 64-bit
root@sawww:dbi/DBI-1.39# gcc -v
Reading specs from
/usr/local/lib/gcc-lib/sparcv9-sun-solaris2.8/3.3.2/specs
Configured with: ../gcc-3.3.2/configure --disable-nls
--host=sparcv9-sun-solaris2.8 --with-libiconv-prefix=/usr/local
Thread model: posix
gcc version 3.3.2

Perl: 5.8.2 64-bit, with threads.
root@sawww:dbi/DBI-1.39# perl -V
Summary of my perl5 (revision 5.0 version 8 subversion 2) configuration:
  Platform:
    osname=solaris, osvers=2.8, archname=sun4-solaris-thread-64
    uname='sunos sawww 5.8 generic sun4u sparc sunw,ultrasparc-iii-cengine
'
    config_args=''
    hint=recommended, useposix=true, d_sigaction=define
    usethreads=define use5005threads=define useithreads=undef
usemultiplicity=undef
    useperlio=define d_sfio=undef uselargefiles=define usesocks=undef
    use64bitint=define use64bitall=define uselongdouble=undef
    usemymalloc=n, bincompat5005=undef
  Compiler:
    cc='gcc', ccflags ='-D_REENTRANT -fno-strict-aliasing
-I/usr/local/include -mcpu=v9 -m64 -Wa,-xarch=v9  -D_LARGEFILE_SOURCE
-D_FILE_OFFSET_BITS=64',
    optimize='-O',
    cppflags='-D_REENTRANT -fno-strict-aliasing -I/usr/local/include'
    ccversion='', gccversion='3.3.2', gccosandvers='solaris2.8'
    intsize=4, longsize=8, ptrsize=8, doublesize=8, byteorder=87654321
    d_longlong=define, longlongsize=8, d_longdbl=define, longdblsize=16
    ivtype='long', ivsize=8, nvtype='double', nvsize=8, Off_t='off_t',
lseeksize=8
    alignbytes=8, prototype=define
  Linker and Libraries:
    ld='gcc', ldflags =' -L/usr/local/lib '
    libpth=/usr/local/lib /usr/lib /usr/ccs/lib
    libs=-lsocket -lnsl -ldl -lm -lpthread -lc
    perllibs=-lsocket -lnsl -ldl -lm -lpthread -lc
    libc=/usr/lib/sparcv9/libc.so, so=so, useshrplib=false,
libperl=libperl.a
    gnulibc_version=''
  Dynamic Linking:
    dlsrc=dl_dlopen.xs, dlext=so, d_dlsymun=undef, ccdlflags=' '
    cccdlflags='-fPIC', lddlflags='-G -L/usr/local/lib'


Characteristics of this binary (from libperl):
  Compile-time options: USE_5005THREADS USE_64_BIT_INT USE_64_BIT_ALL
USE_LARGE_FILES PERL_IMPLICIT_CONTEXT
  Built under solaris
  Compiled at Dec 12 2003 14:01:21
  @INC:
    /usr/local/lib/perl5/5.8.2/sun4-solaris-thread-64
    /usr/local/lib/perl5/5.8.2
    /usr/local/lib/perl5/site_perl/5.8.2/sun4-solaris-thread-64
    /usr/local/lib/perl5/site_perl/5.8.2
    /usr/local/lib/perl5/site_perl
    .

----------------------------------------------------------

When I run `perl Makefile.PL' , the command is aborted with a suggestion
to upgrade to "perl 5.8.2 or later" which is what I already have. I know
this is because of the threads, but I need them, although not necessarily
for DBI module.

So following the instruction, I tried to use
perl Makefile.PL -nothread

Compilation failed:
root@sawww:dbi/DBI-1.39# make
cp Changes blib/lib/DBI/Changes.pm
cp dbd_xsh.h blib/arch/auto/DBI/dbd_xsh.h
cp lib/DBI/FAQ.pm blib/lib/DBI/FAQ.pm
cp Driver_xst.h blib/arch/auto/DBI/Driver_xst.h
cp lib/DBD/Proxy.pm blib/lib/DBD/Proxy.pm
cp lib/DBI/Const/GetInfo/ANSI.pm blib/lib/DBI/Const/GetInfo/ANSI.pm
cp DBIXS.h blib/arch/auto/DBI/DBIXS.h
cp lib/DBI/Const/GetInfoReturn.pm blib/lib/DBI/Const/GetInfoReturn.pm
cp DBI.pm blib/lib/DBI.pm
cp lib/DBD/Sponge.pm blib/lib/DBD/Sponge.pm
cp lib/DBI/Const/GetInfoType.pm blib/lib/DBI/Const/GetInfoType.pm
cp lib/DBI/W32ODBC.pm blib/lib/DBI/W32ODBC.pm
cp lib/DBI/DBD/Metadata.pm blib/lib/DBI/DBD/Metadata.pm
cp lib/DBI/Const/GetInfo/ODBC.pm blib/lib/DBI/Const/GetInfo/ODBC.pm
cp lib/DBI/ProfileDumper/Apache.pm blib/lib/DBI/ProfileDumper/Apache.pm
cp lib/Bundle/DBI.pm blib/lib/Bundle/DBI.pm
cp lib/DBI/Profile.pm blib/lib/DBI/Profile.pm
cp lib/DBI/ProfileDumper.pm blib/lib/DBI/ProfileDumper.pm
cp Driver.xst blib/arch/auto/DBI/Driver.xst
cp lib/DBI/ProxyServer.pm blib/lib/DBI/ProxyServer.pm
cp dbipport.h blib/arch/auto/DBI/dbipport.h
cp lib/DBD/NullP.pm blib/lib/DBD/NullP.pm
cp lib/DBI/DBD.pm blib/lib/DBI/DBD.pm
cp lib/Win32/DBIODBC.pm blib/lib/Win32/DBIODBC.pm
cp lib/DBI/PurePerl.pm blib/lib/DBI/PurePerl.pm
cp lib/DBD/ExampleP.pm blib/lib/DBD/ExampleP.pm
cp dbi_sql.h blib/arch/auto/DBI/dbi_sql.h
cp lib/DBI/ProfileData.pm blib/lib/DBI/ProfileData.pm
/usr/local/bin/perl -p -e "s/~DRIVER~/Perl/g"
blib/arch/auto/DBI/Driver.xst > Perl.xsi
/usr/local/bin/perl /usr/local/lib/perl5/5.8.2/ExtUtils/xsubpp  -typemap
/usr/local/lib/perl5/5.8.2/ExtUtils/typemap -typemap typemap  Perl.xs >
Perl.xsc && mv Perl.xsc Perl.c
gcc -c   -D_REENTRANT -fno-strict-aliasing -I/usr/local/include -mcpu=v9
-m64 -Wa,-xarch=v9 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -O
-DVERSION=\"1.39\" -DXS_VERSION=\"1.39\" -fPIC
"-I/usr/local/lib/perl5/5.8.2/sun4-solaris-thread-64/CORE"  -Wall
-Wno-comment -DDBI_NO_THREADS Perl.c
/usr/local/bin/perl /usr/local/lib/perl5/5.8.2/ExtUtils/xsubpp  -typemap
/usr/local/lib/perl5/5.8.2/ExtUtils/typemap -typemap typemap  DBI.xs >
DBI.xsc && mv DBI.xsc DBI.c
gcc -c   -D_REENTRANT -fno-strict-aliasing -I/usr/local/include -mcpu=v9
-m64 -Wa,-xarch=v9 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -O
-DVERSION=\"1.39\" -DXS_VERSION=\"1.39\" -fPIC
"-I/usr/local/lib/perl5/5.8.2/sun4-solaris-thread-64/CORE"  -Wall
-Wno-comment -DDBI_NO_THREADS DBI.c
DBI.xs: In function `dbih_set_attr_k':
DBI.xs:1280: error: `thr' undeclared (first use in this function)
DBI.xs:1280: error: (Each undeclared identifier is reported only once
DBI.xs:1280: error: for each function it appears in.)
DBI.xs:1282: warning: left-hand operand of comma expression has no effect
make: *** [DBI.o] Error 1


------------------------------------------------------------

After this failed, I started with a freshly opened tarball, and decided to
try and build threaded version of the module regardless, since I do run
the recommended perl 5.8.2. In the Makefile.PL, I commented out lines 86
and 89:
86 #       die "*** ABORTED.\n";
89 #    $::opt_thread = 0;

Then I ran
perl Makefile.PL
make

Compilation failed again:

root@sawww:dbi/DBI-1.39# make
cp Changes blib/lib/DBI/Changes.pm
cp dbd_xsh.h blib/arch/auto/DBI/dbd_xsh.h
cp lib/DBI/FAQ.pm blib/lib/DBI/FAQ.pm
cp Driver_xst.h blib/arch/auto/DBI/Driver_xst.h
cp lib/DBD/Proxy.pm blib/lib/DBD/Proxy.pm
cp lib/DBI/Const/GetInfo/ANSI.pm blib/lib/DBI/Const/GetInfo/ANSI.pm
cp DBIXS.h blib/arch/auto/DBI/DBIXS.h
cp lib/DBI/Const/GetInfoReturn.pm blib/lib/DBI/Const/GetInfoReturn.pm
cp DBI.pm blib/lib/DBI.pm
cp lib/DBD/Sponge.pm blib/lib/DBD/Sponge.pm
cp lib/DBI/Const/GetInfoType.pm blib/lib/DBI/Const/GetInfoType.pm
cp lib/DBI/W32ODBC.pm blib/lib/DBI/W32ODBC.pm
cp lib/DBI/DBD/Metadata.pm blib/lib/DBI/DBD/Metadata.pm
cp lib/DBI/Const/GetInfo/ODBC.pm blib/lib/DBI/Const/GetInfo/ODBC.pm
cp lib/DBI/ProfileDumper/Apache.pm blib/lib/DBI/ProfileDumper/Apache.pm
cp lib/Bundle/DBI.pm blib/lib/Bundle/DBI.pm
cp lib/DBI/Profile.pm blib/lib/DBI/Profile.pm
cp lib/DBI/ProfileDumper.pm blib/lib/DBI/ProfileDumper.pm
cp Driver.xst blib/arch/auto/DBI/Driver.xst
cp lib/DBI/ProxyServer.pm blib/lib/DBI/ProxyServer.pm
cp dbipport.h blib/arch/auto/DBI/dbipport.h
cp lib/DBD/NullP.pm blib/lib/DBD/NullP.pm
cp lib/DBI/DBD.pm blib/lib/DBI/DBD.pm
cp lib/Win32/DBIODBC.pm blib/lib/Win32/DBIODBC.pm
cp lib/DBI/PurePerl.pm blib/lib/DBI/PurePerl.pm
cp lib/DBD/ExampleP.pm blib/lib/DBD/ExampleP.pm
cp dbi_sql.h blib/arch/auto/DBI/dbi_sql.h
cp lib/DBI/ProfileData.pm blib/lib/DBI/ProfileData.pm
/usr/local/bin/perl -p -e "s/~DRIVER~/Perl/g"
blib/arch/auto/DBI/Driver.xst > Perl.xsi
/usr/local/bin/perl /usr/local/lib/perl5/5.8.2/ExtUtils/xsubpp  -typemap
/usr/local/lib/perl5/5.8.2/ExtUtils/typemap -typemap typemap  Perl.xs >
Perl.xsc && mv Perl.xsc Perl.c
gcc -c   -D_REENTRANT -fno-strict-aliasing -I/usr/local/include -mcpu=v9
-m64 -Wa,-xarch=v9 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -O
-DVERSION=\"1.39\" -DXS_VERSION=\"1.39\" -fPIC
"-I/usr/local/lib/perl5/5.8.2/sun4-solaris-thread-64/CORE"  -Wall
-Wno-comment Perl.c
/usr/local/bin/perl /usr/local/lib/perl5/5.8.2/ExtUtils/xsubpp  -typemap
/usr/local/lib/perl5/5.8.2/ExtUtils/typemap -typemap typemap  DBI.xs >
DBI.xsc && mv DBI.xsc DBI.c
gcc -c   -D_REENTRANT -fno-strict-aliasing -I/usr/local/include -mcpu=v9
-m64 -Wa,-xarch=v9 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -O
-DVERSION=\"1.39\" -DXS_VERSION=\"1.39\" -fPIC
"-I/usr/local/lib/perl5/5.8.2/sun4-solaris-thread-64/CORE"  -Wall
-Wno-comment DBI.c
DBI.xs: In function `dbih_set_attr_k':
DBI.xs:1280: error: `thr' undeclared (first use in this function)
DBI.xs:1280: error: (Each undeclared identifier is reported only once
DBI.xs:1280: error: for each function it appears in.)
DBI.xs:1282: warning: left-hand operand of comma expression has no effect
make: *** [DBI.o] Error 1

------------------------------------------------------------------

The error is the same whether or not thread support is requested.

I also tried several previous versions of DBI - 1.38, 1.37, 1.35 - with
the same result.

So where do I go from here?

Any help will be appreciated. Since I am not part of this mailing list,
please do reply directly to me.

Thanks,

Andy

Dr Andy Tsouladze
Sr Unix SysAdmin
UAL Loyalty Services

