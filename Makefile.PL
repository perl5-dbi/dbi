#!/usr/bin/perl
# -*- perl -*-
#
# $Id$
#
#  Copyright (c) 2024-2025  DBI Team
#  Copyright (c) 1994-2024  Tim Bunce  Ireland
#
# See COPYRIGHT section in DBI.pm for usage and distribution rights.

use 5.008_001;

use ExtUtils::MakeMaker 5.16, qw(WriteMakefile $Verbose prompt);
use Getopt::Long;
use Config;
use File::Find;
use File::Spec;
use strict;

use lib "lib"; # for use DBI::DBD
use DBI::DBD;

$| = 1;
$^W = 1;
my $os = $^O;
my $osvers = $Config{osvers};
$osvers =~ s/^\s*(\d+\.\d+).*/$1/;  # drop sub-sub-version: 2.5.1 -> 2.5
my $ext_pl = $^O eq "VMS" ? ".pl" : "";
my $is_developer = (-d ".git" && -f "MANIFEST.SKIP");

$::opt_v = 0;
$::opt_thread = $Config{useithreads};	# thread if we can, use "-nothread" to disable
$::opt_g = 0;
$::opt_g = 1 if $is_developer && $ENV{LOGNAME} && $ENV{LOGNAME} eq "timbo"; # it's me! (probably)

GetOptions (qw(v! g! thread!))  or die "Invalid arguments\n";

$::opt_g &&= "-g";  # convert to actual string

if (($ENV{LANG}||"") =~ m/utf-?8/i) {
    print "\n";
    print "*** Your LANG environment variable is set to '$ENV{LANG}'\n";
    print "*** This may cause problems for some perl installations.\n";
    print "*** If you get test failures, please try again with LANG unset.\n";
    print "*** If that then works, please email dbi-dev\@perl.org with details\n";
    print "*** including the output of 'perl -V'\n";
    print "\n";
    sleep 1;
    }

if ($^O eq "MSWin32" && $] < 5.012 && $File::Spec::VERSION < 3.31) {
    warn "Windows requires File::Spec-3.31, which is CORE as of perl-5.11.3\n";
    warn "As this is just perl-$] with File::Spec-$File::Spec::VERSION\n";
    exit 1;
    }

my %opts = (
    NAME                      => "DBI",
    AUTHOR                    => 'DBI team (dbi-users@perl.org)',
    VERSION_FROM              => "DBI.pm",
    ABSTRACT_FROM             => "DBI.pm",
    MIN_PERL_VERSION          => "5.008001",
    BUILD_REQUIRES            => {
        "ExtUtils::MakeMaker" => "6.48",
        "Test::Simple"        => "0.90",
	},
    META_MERGE                => {
	resources             => {
	    repository        => "https://github.com/perl5-dbi/dbi",
	    bugtracker        => "https://github.com/perl5-dbi/dbi/issues",
	    MailingList       => 'mailto:dbi-dev@perl.org',
	    license           => "http://dev.perl.org/licenses/",
	    homepage          => "http://dbi.perl.org/",
	    IRC               => "irc://irc.perl.org/#dbi",
	    },
	suggests              => {
	    "RPC::PlServer"   => 0.2020,
	    "Net::Daemon"     => 0,
	    "SQL::Statement"  => 1.414,
	    "Clone"           => 0.47,
	    "MLDBM"           => 0,
	    "DB_File"         => 0,
	    },
	},
    LICENSE                   => "perl",
    EXE_FILES                 => [ "dbiproxy$ext_pl", "dbiprof$ext_pl", "dbilogstrip$ext_pl" ],
    DIR                       => [ ],
    dynamic_lib               => {
	OTHERLDFLAGS          => "$::opt_g",
	},
    clean                     => {
	FILES                 => "\$(DISTVNAME) Perl.xsi t/zv*_*.t dbi__null_test_tmp* test_output_*"
                ." dbiproxy$ext_pl dbiprof$ext_pl dbilogstrip$ext_pl dbiproxy.*log dbitrace.log dbi*.prof ndtest.prt" },
    dist                      => {
	DIST_DEFAULT          => "clean distcheck disttest tardist",
	PREOP                 => '$(MAKE) -f Makefile.old distdir',
	COMPRESS              => "gzip -v9", SUFFIX => "gz",
	},
    macro                     => {
	TARFLAGS              => "--format=ustar -c -v -f",
	},
    );
$opts{CAPI} = "TRUE" if $Config{archname} =~ /-object\b/i;

if (my $gccversion = $Config{gccversion}) {	# ask gcc to be more pedantic
    if ($gccversion =~ m/ clang ([0-9][-0-9.]*)/i) {
	print "Your perl was compiled with Clang (version $1). As this is not GCC, version checking is skipped.\n";
	# https://clang.llvm.org/docs/DiagnosticsReference.html
	$opts{DEFINE} .= " -W -Wall -Wpointer-arith";
	$opts{DEFINE} .= " -Wno-comment -Wno-sign-compare -Wno-cast-qual";
	$opts{DEFINE} .= " -Wmissing-noreturn -Wno-unused-parameter";
	$opts{DEFINE} .= " -Wno-compound-token-split-by-macro -Wno-constant-conversion";
	$opts{DEFINE} .= " -Wno-implicit-const-int-float-conversion";
	if ($is_developer && $::opt_g) {
	    $opts{DEFINE} .= " -Wmissing-prototypes";
	    }
	}
    else {
	warn "WARNING: Your GNU C $gccversion compiler is very old. Please upgrade it and rebuild perl.\n"
	    if $gccversion =~ m/^\D*(1|2\.[1-8])\b/;
	print "Your perl was compiled with gcc (version $Config{gccversion}), okay.\n";
	$gccversion =~ s/[^\d\.]//g; # just a number please
	$opts{DEFINE} .= " -W -Wall -Wpointer-arith";
	$opts{DEFINE} .= " -Wno-comment -Wno-sign-compare -Wno-cast-qual";
	$opts{DEFINE} .= " -Wmissing-noreturn -Wno-unused-parameter" if $gccversion ge "3.0";
	if ($is_developer && $::opt_g) {
	    $opts{DEFINE} .= " -DPERL_GCC_PEDANTIC -ansi -pedantic"  if $gccversion ge "3.0";
	    $opts{DEFINE} .= " -Wdisabled-optimization -Wformat"     if $gccversion ge "3.0";
	    $opts{DEFINE} .= " -Wmissing-prototypes";
	    }
	}
    }

$opts{DEFINE} .= " -DDBI_NO_THREADS" unless $::opt_thread;

# HP-UX 9 cannot link a non-PIC object file into a shared library.
# Since the # .a libs that Oracle supplies contain non-PIC object
# files, we sadly have to build static on HP-UX 9 :(
if ($os eq "hpux" and $osvers < 10) {
    $opts{LINKTYPE} = "static";
    print "Warning: Forced to build static not dynamic on $os $osvers.\a\n";
    print "** Note: DBI will be built *into* a NEW perl binary. You MUST use that new perl.\n";
    print "         See README and Makefile.PL for more information.\a\n";
    }

if ($os eq "MSWin32"  &&  $Config{libs} =~ /\bPerlCRT.lib\b/ &&  -f "$Config{archlib}/CORE/PerlCRT.lib") {
    # ActiveState Perl needs this; should better be done in MakeMaker, but
    # as a temporary workaround it seems ok.
    $opts{LIBS} = "-L$Config{archlib}/CORE";
    }

# Set aside some values for post_initialize() in package MY
my ($cfg_privlibexp, $cfg_archlibexp, $cfg_sitelibexp, $cfg_sitearchexp, $cfg_man3direxp) =
     @Config{qw( privlibexp archlibexp sitelibexp sitearchexp man3direxp )};
for ($cfg_privlibexp, $cfg_archlibexp, $cfg_sitelibexp, $cfg_sitearchexp, $cfg_man3direxp) {
     $_ = "" unless defined $_;
    }

my $conflictMsg = <<EOCM;
***
    This version of DBI conflicts with the version of
    module %s (%s) you have installed.

    It's strongly recommended that you update it after
    installing this version of DBI.
***
EOCM

sub CheckConflicts {
    my %params    = @_;
    my %conflicts = %{ $params{CONFLICTS} };
    my $found     = 0;

    while (my ($module, $version) = each %conflicts) {
        undef $@;
        eval "require $module";
        $@ and next;

        my $installed = eval "\$" . $module . "::VERSION";
        $installed gt $version and next;

	++$found;
	my $msg = $conflictMsg;
	my $warning = sprintf( $msg, $module, $installed );
	warn $warning;
	}

    return !$found;
    } # CheckConflicts

sub WriteMakefile1 {
    #Written by Alexandr Ciornii, version 0.21. Added by eumm-upgrade.
    my %params       = @_;
    my $eumm_version = $ExtUtils::MakeMaker::VERSION;
    $eumm_version = eval $eumm_version;
    die "EXTRA_META is deprecated" if  exists $params{EXTRA_META};
    die "License not specified"    if !exists $params{LICENSE};
    if ($params{BUILD_REQUIRES} and $eumm_version < 6.5503) {
        # EUMM 6.5502 has problems with BUILD_REQUIRES
        $params{PREREQ_PM} = { %{ $params{PREREQ_PM} || {} }, %{ $params{BUILD_REQUIRES} } };
        delete $params{BUILD_REQUIRES};
	}

    # more or less taken from Moose' Makefile.PL
    if ($params{CONFLICTS}) {
        my $ok = CheckConflicts (%params);
        exit 0 if ($params{PREREQ_FATAL} and not $ok);
        my $cpan_smoker = grep { $_ =~ m/(?:CR_SMOKER|CPAN_REPORTER|AUTOMATED_TESTING)/ } keys %ENV;
        unless ($cpan_smoker || $ENV{PERL_MM_USE_DEFAULT}) {
            sleep 4 unless $ok;
	    }
	%{$params{META_MERGE}{conflicts}} = %{$params{CONFLICTS}};
        delete $params{CONFLICTS};
	}

    delete $params{CONFIGURE_REQUIRES} if $eumm_version < 6.52;
    delete $params{MIN_PERL_VERSION}   if $eumm_version < 6.48;
    delete $params{META_MERGE}         if $eumm_version < 6.46;
    delete $params{META_ADD}           if $eumm_version < 6.46;
    delete $params{LICENSE}            if $eumm_version < 6.31;

    WriteMakefile (%params);
    } # WriteMakefile1

$Verbose = $::opt_v;
WriteMakefile1 (
    dbd_edit_mm_attribs (\%opts, {
	create_pp_tests   => 1,
	create_nano_tests => 1,
	create_gap_tests  => 1,
	})
    );
# WriteMakefile call is last thing executed
# so return value is propagated

# =====================================================================

package MY;

sub postamble {
warn <<EOT;

    I see you're using perl $] on $Config::Config{archname}, okay.
    Remember to actually *read* the README file!
    Use  'make' to build the software (dmake or nmake on Windows).
    Then 'make test' to execute self tests.
    Then 'make install' to install the DBI and then delete this working
    directory before unpacking and building any DBD::* drivers.

EOT
warn <<EOT if $os eq "MSWin32";
    Windows users need to use the correct make command.
    That may be nmake or dmake depending on which Perl you are using.
    If using the Win32 ActiveState build then it is recommended that you
    use the ppm utility to fetch and install a prebuilt DBI instead.

EOT

    # This here instead of post_constants, as otherwise xt/ would be tested *before* t/
    my $min_vsn = ($] >= 5.024 && -d "xt" && -d "sandbox" && ($ENV{AUTOMATED_TESTING} || 0) != 1)
	? join "\n" =>
	    'test ::',
	    '	-@env TEST_FILES="xt/*.t" make -e test_dynamic',
	    ''
	: "";

    return join "\n" =>
	$min_vsn;
    } # postamble

sub libscan {
    my ($self, $path) = @_;
    ($path =~ /\~$|\B\.git\b/) ? undef : $path;
    } # libscan

sub const_cccmd {
    my $self = shift;
    local ($_) = $self->SUPER::const_cccmd (@_);
    # If perl Makefile.PL *-g* then switch on debugging
    if ($::opt_g) {
	s/\s-O\d?\b//;      # delete optimise option
	s/\s-/ -g -/;       # add -g option
	}
    $_;
    } # const_cccmd

sub post_initialize {
    my $self = shift;

    if ($cfg_privlibexp ne $cfg_sitelibexp) {
	# this block could probably be removed now
	my %old;
	File::Find::find (sub {
	    local $_ = $File::Find::name;
	    s{\\}{/}g if $os eq "MSWin32";
	    $File::Find::prune = 1, return
		if -d $_ && ($_ eq $cfg_sitelibexp  ||
			     $_ eq $cfg_sitearchexp ||
			     $_ eq $cfg_man3direxp);
	    ++$old{$_} if m{\bDB(I|D$)}; # DBI files, but just DBD dirs
	    }, $cfg_privlibexp, $cfg_archlibexp);
	if (%old) {
	    warn "
Warning: By default new modules are installed into your 'site_lib'
         directories. Since site_lib directories come after the normal library
         directories you must delete old DBI files and directories from your
         'privlib' and 'archlib' directories and their auto subdirectories.

Reinstall DBI and your DBD::* drivers after deleting the old directories.

Here's a list of probable old files and directories:

 " . join ("\n ", (sort keys %old), "\n" );
	    }
	}

    # install files that DBD's may need
    File::Find::find (sub {

	# may be '.' or '[]' depending on File::Find version
	$_ = "." if $^O eq "VMS" && $_ eq File::Spec->curdir;

	$File::Find::prune = 1, return if -d $_ && "." ne $_;
	$self->{PM}->{$_} = File::Spec->catfile ($self->{INST_ARCHAUTODIR}, $_)
	    if ".h" eq substr ($_, -2) || ".xst" eq substr ($_, -4);
        }, ".");

    delete $self->{$_}{"git-svn-vsn.pl"} for qw( PM MAN3PODS );

    return "";
    } # post_initialize

sub post_constants {
    my $self = shift;

    # ensure that Driver.xst and related code gets tested
    my $xst = main::dbd_postamble ();
    $xst =~ s/\$\(BASEEXT\)/Perl/g;
    $xst .= '
dbixs_rev.h: DBIXS.h Driver_xst.h dbipport.h dbivport.h dbixs_rev.pl
	$(PERL) dbixs_rev.pl

DBI.c: Perl$(OBJ_EXT)

# make Changes file available as installed pod docs "perldoc DBI::Changes"
inst_libdbi = ' . File::Spec->catdir  ($self->{INST_LIB}, 'DBI') . '
changes_pm1 = ' . File::Spec->catfile ('lib', 'DBI', 'Changes.pm') . '
changes_pm2 = ' . File::Spec->catfile ($self->{INST_LIB}, 'DBI', 'Changes.pm') . '
'.q{

config :: $(changes_pm1)
	$(NOECHO) $(NOOP)

$(changes_pm1): ChangeLog
	$(MKPATH) $(inst_libdbi)
	$(RM_F) $(changes_pm1) $(changes_pm2)
	perl changes2pm.pl
$(changes_pm2): $(changes_pm1)
	$(CP)   $(changes_pm1) $(changes_pm2)

ptest:  all
	prove --blib --jobs 8 --shuffle

.PHONY:	doc change changes spellcheck checkpod newdist
changes:	$(changes_pm1)
doc:
	perl doc/make-doc.pl --pod
spellcheck checkpod:	doc
	pod-spell-check -i -a doc/*.pod

dbipport:
	perl sandbox/genPPPort_h.pl
ppport:		dbipport.h
	perl dbipport.h --compat-version=5.8.1 DBI.xs

# make dist does not remove existing .tar.gz causing questions
newdist:
	-@rm -f $(DISTVNAME).tar.gz $(DISTVNAME).tgz
tgzdist:	changes spellcheck newdist dist
	-@mv -f $(DISTVNAME).tar.gz $(DISTVNAME).tgz
	-@cpants_lint.pl $(DISTVNAME).tgz
	-@rm -f Debian_CPANTS.txt
};

    return $xst;
    } # post_constants

1;
