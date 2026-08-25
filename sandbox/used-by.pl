#!/pro/bin/perl

use 5.26.0;
use warnings;

our $VERSION = "2.00 - 20200209";

sub usage {
    my $err = shift and select STDERR;
    say "usage: $0 [--list]";
    exit $err;
    } # usage

use blib;
use Cwd;
use LWP;
use LWP::UserAgent;
use HTML::TreeBuilder;
use CPAN;
use Capture::Tiny qw( :all );
use Term::ANSIColor qw(:constants :constants256);
use Test::More;

use Getopt::Long qw(:config bundling passthrough);
GetOptions (
    "help|?"	=> sub { usage (0); },
    "V|version"	=> sub { say $0 =~ s{.*/}{}r, " [$VERSION]"; exit 0; },
    "a|all!"	=> \ my $opt_a,	# Also build for known FAIL (they might have fixed it)
    "l|list!"	=> \ my $opt_l,
    "d|dir=s"	=> \(my $opt_d = "used-by-t"),
    ) or usage (1);

my $tm = shift // do {
    (my $d = getcwd) =~ s{.*CPAN/([^/]+)(?:/.*)?}{$1};
    $d;
    } or die "No module to check\n";

diag ("Testing used-by for $tm\n");
my %tm = map { $_ => 1 } qw( );

if ($opt_d) {
    mkdir $opt_d, 0775;
    unlink glob "$opt_d/*.t";
    -d $opt_d or die "$opt_d cannot be used as test folder\n";
    }

$| = 1;
$ENV{AUTOMATED_TESTING}   = 1;
$ENV{PERL_USE_UNSAFE_INC} = 1; # My modules are not responsible
# Skip all dists that
# - are FAIL not due to the mudule being tested (e.g. POD or signature mismatch)
# - that require interaction (not dealt with in distroprefs or %ENV)
# - are not proper dists (cannot use CPAN's ->test)
# - require external connections or special devices
my %skip = $opt_a ? () : map { $_ => 1 } (
    # Data-Peek
    "GSM-Gnokii",			# External device
    # DBD-CSV
    "ASNMTAP",
    "Gtk2-Ex-DBITableFilter",		# Unmet prerequisites
    # Text-CSV_XS
    "ACME-QuoteDB",			# ::CSV Possible precedence issues
    "App-Framework",			# Questions
    "App-mojopaste",			# failing internet connections
    "ASNMTAP",				# Questions
    "Business-Shipping-DataTools",	# Questions and unmet prereqs
    "Catalyst-TraitFor-Model-DBIC-Schema-QueryLog-AdoptPlack", # maint/Maker.pm
    "CGI-Application-Framework",	# Unmet prerequisites
    "chart",				# Questions (in Apache-Wyrd)
    "CohortExplorer",			# Unmet prerequisites
    "Connector",			# No Makefile.PL (in Annelidous)
    "DBIx-Class-DigestColumns",		# unmet prereqs
    "DBIx-Class-FilterColumn-ByType",	# ::CSV - unmet prereqs
    # DBIx-Class-EncodedColumn",	# Busted configuration
    "DBIx-Class-FormTools",		# ::CSV POD
    "DBIx-Class-FromSledge",		# ::CSV Spelling
    "DBIx-Class-Graph",			# won't build at all
    "DBIx-Class-InflateColumn-Serializer-CompressJSON",	# ::CSV POD
    "DBIx-Class-Loader",		# ::CSV Deprecated
    "DBIx-Class-QueryProfiler",		# ::CSV - Kwalitee test (2011)
    "DBIx-Class-RDBOHelpers",		# ::CSV - Unmet prereqs
    "DBIx-Class-Schema-Slave",		# ::CSV - Tests br0ken
    "DBIx-Class-Snowflake",		# ::CSV - Bad tests. SQLite fail
    "DBIx-Class-StorageReadOnly",	# ::CSV - POD coverage
    "DBIx-NoSQL",			# ::CSV - Syntax
    "DBIx-Patcher",			# ::CSV - Own tests fail
    "dbMan",				# Questions
    "Finance-Bank-DE-NetBank",		# Module signatures
    "FormValidator-Nested",		# ::CSV - Questions
    "FreeRADIUS-Database",		# ::CSV - Questions
    "Fsdb",				# ::CSV -
    "Geo-USCensus-Geocoding",		# '302 Found'
    "Gtk2-Ex-DBITableFilter",		# Unmet prerequisites
    "Gtk2-Ex-Threads-DBI",		# Distribution is incomplete
    "hwd",				# Own tests fail
    "Iterator-BreakOn",			# ::CSV - Syntax, POD, badness
    "Mail-Karmasphere-Client",		# ::CSV - No karmaclient
    "Module-CPANTS-ProcessCPAN",	# ::CSV - Questions
    "Module-CPANTS-Site",		# ::CSV - Unmet prerequisites
    "Net-IPFromZip",			# Missing zip file(s)
    "Parse-CSV-Colnames",		# ::CSV - Fails because of Parse::CSV
    "Pcore",				# Unmet prereqs (common::header)
    "Plack-Middleware-DBIC-QueryLog",	# maint/Maker.pm
    "Plack-Middleware-Debug-DBIC-QueryLog",	# maint/Maker.pm
    "RDF-RDB2RDF",			# ::CSV - Bad tests
    "RT-Extension-Assets-Import-CSV",	# Questions
    "RT-View-ConciseSpreadsheet",	# Questions
    "Serge",				# Questions in Build.PL ?
    "Template-Provider-DBIC",		# weird
    "Template-Provider-PrefixDBIC",	# weird
    "Test-DBIC",			# ::CSV - Insecure -T in C3
#   "Text-CSV-Encoded",			# ::CSV - Encoding, patch filed at RT
    "Text-CSV_PP-Simple",		# ::CSV - Syntax errors, bad archive
#   "Text-CSV-Track",			# Encoding, patch filed at RT
    "Text-ECSV",			# POD, spelling
    "Text-MeCab",			# Questions
    "Text-TEI-Collate",			# Unmet prerequisites
    "Text-Tradition",			# Unmet prerequisites
    "Text-xSV-Slurp",			# 5.26 incompat, unmaintained
    "Tripletail",			# Makefile.PL broken
    "VANAMBURG-SEMPROG-SimpleGraph",	# Own tests fail
    "WebService-FuncNet",		# ::CSV - WSDL 404, POD
    "Webservice-InterMine",		# Unmet prerequisites
    "WebService-ReutersConnect",	# XML errors
    "WWW-Analytics-MultiTouch",		# Unmet prerequisites
    "XAS",				# ::CSV - No STOMP MQ
    "XAS-Model",			# ::CSV - No STOMP MQ
    "XAS-Spooler",			# ::CSV - No STOMP MQ
    "xDash",				# Questions
#   "xls2csv",
    "Xymon-DB-Schema",			# ::CSV - Bad prereqs
    "Xymon-Server-ExcelOutages",	# ::CSV - Questions
    "YamlTime",				# Unmet prerequisites
    );
$skip{s/-/::/gr} = 1 for keys %skip;
my %add = (
    "Text-CSV_XS"  => [				# Using Text::CSV, thus
	"Text-CSV-Auto",			# optionally _XS
	"Text-CSV-R",
	"Text-CSV-Slurp",
	],
    );

my $ua  = LWP::UserAgent->new (agent => "Opera/12.15");

sub get_from_cpantesters {
    my $m = shift // $tm;
    warn "Get from cpantesters ...\n";
    my @h;
    foreach my $url (
	"http://deps.cpantesters.org/depended-on-by.pl?dist=$m",
	"http://deps.cpantesters.org/depended-on-by.pl?module=$m",
	) {
	my $rsp = $ua->request (HTTP::Request->new (GET => $url));
	unless ($rsp->is_success) {
	    warn "deps failed: ", $rsp->status_line, "\n";
	    next;
	    }
	my $tree = HTML::TreeBuilder->new;
	   $tree->parse_content ($rsp->content);
	foreach my $a ($tree->look_down (_tag => "a", href => qr{query=})) {
	    (my $h = $a->attr ("href")) =~ s{.*=}{};
	    push @h, $h;
	    }
	}
    return @h;
    } # get_from_cpantesters

sub get_from_cpants {
    my $m = shift // $tm;
    warn "Get from cpants ...\n";
    my $url = "http://cpants.cpanauthors.org/dist/$m/used_by";
    my $rsp = $ua->request (HTTP::Request->new (GET => $url));
    unless ($rsp->is_success) {
	warn "cpants failed: ", $rsp->status_line, "\n";
	return;
	}
    my $tree = HTML::TreeBuilder->new;
       $tree->parse_content ($rsp->content);
    my @h;
    foreach my $a ($tree->look_down (_tag => "a", href => qr{/dist/})) {
	(my $h = $a->attr ("href")) =~ s{.*dist/}{};
	$h =~ m{^$m\b} and next;
	push @h, $h;
	}
    @h or diag ("$url might be rebuilding");
    return @h;
    } # get_from_cpants

sub get_from_meta {
    my $m = shift // $tm;
    warn "Get from meta ...\n";
    my $url = "https://metacpan.org/requires/distribution/$m";
    my $rsp = $ua->request (HTTP::Request->new (GET => $url));
    unless ($rsp->is_success) {
	warn "meta failed: ", $rsp->status_line, "\n";
	return;
	}
    my $tree = HTML::TreeBuilder->new;
       $tree->parse_content ($rsp->content);
    my @h;
    foreach my $a ($tree->look_down (_tag => "a", class => "ellipsis",
					href => qr{/release/})) {
	(my $h = $a->attr ("href")) =~ s{.*release/}{};
	$h =~ m{^$m\b} and next;
	push @h, $h;
	}
    return @h;
    } # get_from_meta

sub get_from_all {
    my $m = shift // $tm;
    ( get_from_cpants ($m),
      get_from_cpantesters ($m),
      get_from_meta ($m));
    } # get_from_all

sub get_from_sandbox {
    open my $fh, "<", "sandbox/used-by.txt" or return;
    map { chomp; $_ } <$fh>;
    } # get_from_sandbox

my @h = ( get_from_all (),
	  get_from_sandbox (),
	  @{$add{$tm} || []});

$tm eq "Text-CSV_XS" and push @h, get_from_all ("Text-CSV");

foreach my $h (@h) {
    exists $skip{$h} || $h =~ m{^( $tm (?: $ | / )
				 | Task-
				 | Bundle-
				 | Win32-
				 )\b}x and next;
    (my $m = $h) =~ s/-/::/g;
    $tm{$m} = 1;
    }

warn "fetched ", scalar keys %tm, " keys\n";

unless (keys %tm) {
    ok (1, "No dependents found");
    done_testing;
    exit 0;
    }

my @tm = sort keys %tm;

if ($opt_l) {
    ok (1, $_) for @tm;
    done_testing;
    exit 0;
    }

my %rslt;
foreach my $m (@tm) {
    $skip{$m} and next;
    # diag $m;
    if ($opt_d) {
	open my $fh, ">", "$opt_d/$m.t";
	print $fh <<~"EOT";
		#!$^X
		use 5.12.1;
		use warnings;
		# HARNESS-TIMEOUT-EVENT 300
		use CPAN;
		use Test::More;
		use Capture::Tiny qw( :all );

		my (\$out, \$err, \$ext);
		alarm 300;
		eval {
		    (\$out, \$err, \$ext) = capture {
			CPAN::Shell->expand ("Module", "/$m/")->test;
			};
		    };
		alarm 0;
		is (\$?, 0, '$m');
		if (\$? and \$out) {
		    open my \$fh, ">", "$opt_d/$m.out";
		    print \$fh \$out;
		    close \$fh;
		    }
		if (\$? and \$err) {
		    open my \$fh, ">", "$opt_d/$m.err";
		    print \$fh \$err;
		    close \$fh;
		    }
		done_testing ();
		EOT
	close $fh;
	ok (1, $m);
	}
    else {
	eval {
	    my $mod = CPAN::Shell->expand ("Module", "/$m/") or die $@;
	    local $SIG{ALRM} = sub {
		$rslt{$m} = [ [ $? = 1, 1, "ALARM" ], "", "", "" ];
		};
	    alarm 500;
	    $rslt{$m}    = [ [], capture { $mod->test } ];
	    $rslt{$m}[0] = [ $?, $!, $@ ];
	    alarm 0;
	    };
	# say $? ? RED."FAIL".RESET : GREEN."PASS".RESET;
	is ($?, 0, $m);
	}
    }

if ($opt_d) {
    fork or exec "prove", "-vbt", "-j8", $opt_d;
    #fork or exec "yath", "test", "--no-fork", $opt_d;
    #require App::Yath;
    #@ARGV = ("test", "-PText::CSV_XS", "used-by-t");
    #App::Yath->import (\@ARGV, \$App::Yath::RUN);
    #Test::More::ok ($App::Yath::RUN->(), "Run YATH");
    }

done_testing;
