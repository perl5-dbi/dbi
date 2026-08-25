#!/pro/bin/perl

package genMETA;

our $VERSION = "1.18-20250113";

use 5.014001;
use warnings;
use Carp;

use CPAN::Meta::Converter;
use CPAN::Meta::Validator;
use Data::Peek;
use Date::Calc qw( Delta_Days );
use Encode qw( encode decode );
use File::Find;
use JSON::PP;
use List::Util qw( first );
use Parse::CPAN::Meta;
use Software::Security::Policy::Individual;
use Term::ANSIColor qw(:constants);
use Test::CPAN::Meta::YAML::Version;
use Test::More ();
use Text::Diff;
use YAML::Syck;

sub new {
    my $package = shift;
    return bless { @_ }, $package;
    } # new

sub extract_version {
    my $fh = shift;
    my @vsn;
    while (<$fh>) {
	m/\$VERSION\b/ and push @vsn => $_;
	m{^(?:our\s+)?							# declaration
	   \$VERSION \s*=\s*						# variable
	   ["']? ([0-9._]+)						# version
		 (?:\s* - \s* [0-9]{4}-?[0-9]{2}-?[0-9]{2} \s*)?	# date "0.01 - 20230412"
	   ['"]?
	   \s*;\s*
		 (?:\x23 \s* [0-9]{4}-?[0-9]{2}-?[0-9]{2} \s*)?		# date "0.01"; # 20230502
	   $}x or next;
	return $1;
	}
    # No match on first scan, try without date
    for (@vsn) {
	m{^(?:our\s+)?							# declaration
	   \$VERSION \s*=\s*						# variable
	   ([""'']) ([0-9._]+) \1					# version
	   \s*;
	   }x or next;
	return $2;
	}
    } # extract_version

sub version_from {
    my ($self, $src) = @_;

    $self->{mfpr} = {};
    if (open my $mh, "<", "Makefile.PL") {
	my $mf = do { local $/; <$mh> };

	if ($mf =~ m{\b NAME         \s*=>\s* ["'] (\S+) ['"]}x) {
	    $self->{name} = $1;
	    $self->{name} =~ m/-/ and
		warn RED, "NAME in Makefile.PL contains a -", RESET, "\n";
	    $self->{name} =~ s/::/-/g;
	    }
	if ($mf =~ m{\b DISTNAME     \s*=>\s* ["'] (\S+) ['"]}x) {
	    $self->{name} = $1;
	    }

	if ($mf =~ m{\b VERSION_FROM \s*=>\s* ["'] (\S+) ['"]}x) {
	    my $from = $1;
	    -f $from or
		croak RED, "Makefile wants version from nonexisten $from", RESET, "\n";
	    $self->{from} //= $from;
	    $from eq $self->{from} or
		croak RED, "VERSION_FROM mismatch Makefile.PL ($from) / YAML ($self->{from})", RESET, "\n";
	    }

	if ($mf =~ m[\b PREREQ_PM    \s*=>\s* \{ ( [^}]+ ) \}]x) {
	    my @pr = split m/\n/ => $1;
	    $self->{mfpr} = { map { (m{ \b ["']? (\S+?) ['"]? \s*=>\s* ["']? ([-0-9._]+) ['"]? }x) } grep !m/^\s*#/ => @pr };
	    }

	$mf =~ m{--format=ustar} or
	    warn RED, "TARFLAGS macro is missing", RESET, "\n";
	}

    $src //= $self->{from} or croak "No file to extract version from";

    open my $pm, "<", $src or croak "Cannot read $src";
    my $version = extract_version ($pm) or croak "Cannot extract VERSION from $src\n";
    close $pm;
    $self->{version} = $version;
    return $version
    } # version_from

sub from_data {
    my ($self, @data) = @_;
    $self->{version} or $self->version_from ();
    s/VERSION/$self->{version}/g for @data;
    my ($dsct, $dmod);
    for (@data) {
	s/[ \t]+$//;
	m/^\s*(\w+):$/			and $dsct = $1;
	m/^\s*(\w(?:[\w:]+\w)?):\s+\d/	and $dmod = $1;
	s/\s+#\s*ignore\b\s*[:=]?\s*(\S+)$//i or next;
	$self->{cve_ignore}{$dsct}{$dmod} = $1;
	}
    $self->{yml} = \@data;
    $self->check_yaml ();
    $self->check_provides ();
    #DDumper $self->{cve_ignore};
    return @data;
    } # from_data

sub check_encoding {
    my $self = shift;
    my @tf   = grep m{^(?: change | readme | .*\.pod )}ix => glob "*";
    (my $tf = join ", " => @tf) =~ s/.*\K, / and /;

    print "Check if $tf are still valid UTF8 ...\n";
    foreach my $tf (@tf) {
	open my $fh, "<", $tf or croak "$tf: $!\n";
	my @c = <$fh>;
	my $c = join "" => @c;
	my @e;
	my $s = decode ("utf-8", $c, sub { push @e, shift; });
	if (@e) {
	    my @l;
	    my $n = 0;
	    for (@c) {
		$n++;
		eval { decode ("utf-8", $_, 1) };
		$@ or next;
		$@ =~ s{ at /\S+ line \d+.*}{};
		print BLUE, "$tf:$n\t$_\t$@", RESET;
		}
	    croak "$tf is not valid UTF-8\n";
	    }
	my $u = encode ("utf-8", $s);
	$c eq $u and next;

	my $n;
	$n = 1; $c =~ s/^/$n++ . "\t"/gem;
	$n = 1; $u =~ s/^/$n++ . "\t"/gem;
	croak "$tf: recode makes content differ\n". diff \$c, \$u;
	}
    } # check_encoding

sub check_required {
    my $self = shift;

    my $yml = $self->{h} or croak "No YAML to check";

    warn "Check required and recommended module versions ...\n";
    BEGIN { $V::NO_EXIT = $V::NO_EXIT = 1 } require V;
    my %req = map { %{$yml->{$_}} } grep m/requires/   => keys %{$yml};
    my %rec = map { %{$yml->{$_}} } grep m/recommends/ => keys %{$yml};
    my %sug = map { %{$yml->{$_}} } grep m/suggests/   => keys %{$yml};
    if (my $of = $yml->{optional_features}) {
	foreach my $f (values %{$of}) {
	    my %q = map { %{$f->{$_}} } grep m/requires/   => keys %{$f};
	    my %c = map { %{$f->{$_}} } grep m/recommends/ => keys %{$f};
	    my %s = map { %{$f->{$_}} } grep m/suggests/   => keys %{$f};
	    @req{keys %q} = values %q;
	    @rec{keys %c} = values %c;
	    @sug{keys %s} = values %s;
	    }
	}
    if (my $of = $yml->{prereqs}) {
	foreach my $f (values %{$of}) {
	    my %q = map { %{$f->{$_}} } grep m/requires/   => keys %{$f};
	    my %c = map { %{$f->{$_}} } grep m/recommends/ => keys %{$f};
	    my %s = map { %{$f->{$_}} } grep m/suggests/   => keys %{$f};
	    @req{keys %q} = values %q;
	    @rec{keys %c} = values %c;
	    @sug{keys %s} = values %s;
	    }
	}
    my %vsn = ( %req, %rec, %sug );
    delete @vsn{qw( perl version )};
    for (sort keys %vsn) {
	if (my $mfv = delete $self->{mfpr}{$_}) {
	    $req{$_} eq $mfv or
		croak RED, "PREREQ mismatch for $_ Makefile.PL ($mfv) / YAML ($req{$_})", RESET, "\n";
	    }
	$vsn{$_} eq "0" and next;
	my $v = V::get_version ($_);
	$v eq $vsn{$_} and next;
	printf STDERR "%s%-35s %-6s => %s%s%s\n", BLUE, $_, $vsn{$_}, GREEN, $v, RESET;
	}
    if (my @mfpr = grep { $_ ne "version" } sort keys %{$self->{mfpr}}) {
	croak RED, "Makefile.PL requires @mfpr, YAML does not", RESET, "\n";
	}

    find (sub {
	$File::Find::dir  =~ m{^blib\b}			and return;
	$File::Find::name =~ m{(?:^|/)Bundle/.*\.pm}	or  return;
	if (open my $bh, "<", $_) {
	    warn "Check bundle module versions $File::Find::name ...\n";
	    while (<$bh>) {
		my ($m, $dv) = m/^([A-Za-z_:]+)\s+([0-9.]+)\s*$/ or next;
		my $v = $m eq $self->{name} ? $self->{version} : V::get_version ($m);
		$v eq $dv and next;
		printf STDERR "%s%-35s %-6s => %s%s%s\n", BLUE, $m, $dv, GREEN, $v, RESET;
		}
	    }
	}, glob "*");
    } # check_required

sub check_yaml {
    my $self = shift;

    my @yml = @{$self->{yml}} or croak "No YAML to check";

    warn "Checking generated YAML ...\n" unless $self->{quiet};
    my $h;
    my $yml = join "", @yml;
    eval { $h = Load ($yml) };
    $@ and croak "$@\n";
    $self->{name} //= $h->{name};
    $self->{name} eq  $h->{name} or
	croak RED, "NAME mismatch Makefile.PL / YAML", RESET, "\n";
    $self->{name} =~ s/-/::/g;
    warn "Checking for $self->{name}-$self->{version}\n" unless $self->{quiet};

    $self->{verbose} and print Dump $h;

    my $t = Test::CPAN::Meta::YAML::Version->new (data => $h);
    $t->parse () and
	croak join "\n", "Test::CPAN::Meta::YAML reported failure:", $t->errors, "";

    eval { Parse::CPAN::Meta::Load ($yml) };
    $@ and croak "$@\n";

    $self->{h}    = $h;
    $self->{yaml} = $yml;
    } # check_yaml

sub check_minimum {
    my $self = shift;
    my $reqv = $self->{h}{requires}{perl} || $self->{h}{prereqs}{runtime}{requires}{perl};
    my $locs;

    for (@_) {
	if (ref $_ eq "ARRAY") {
	    $locs = { paths => $_ };
	    }
	elsif (ref $_ eq "HASH") {
	    $locs = $_;
	    }
	else {
	    $reqv = $_;
	    }
	}
    my $paths = (join ", " => @{($locs // {})->{paths} // []}) || "default paths";

    $reqv or croak "No minimal required version for perl";
    my $tmv = 0;
    $reqv > 5.009 and eval "use Test::MinimumVersion::Fast; \$tmv = 1";
    $tmv          or  eval "use Test::MinimumVersion;";
    print "Checking if $reqv is still OK as minimal version for $paths\n";
    # All other minimum version checks done in xt
    Test::More::subtest "Minimum perl version $reqv" => sub {
	all_minimum_version_ok ($reqv, $locs);
	} or warn RED, "\n### Use 'perlver --blame' on the failing file(s)\n\n", RESET;
    } # check_minimum

sub check_provides {
    my $self = shift;
    my $prov = $self->{h}{provides};

    print "Check distribution module versions ...\n";

    $prov or croak RED, "META does not contain a provides section", RESET, "\n";

    ref $prov eq "HASH" or
	croak RED, "The provides section in META is not a HASH", RESET, "\n";

    my $fail = 0;
    foreach my $m (sort keys %{$prov}) {
	my ($file, $pvsn) = @{$prov->{$m}}{qw( file version )};
	unless ($file) {
	    $fail++;
	    say RED, "  provided $m does not refer to a file", RESET;
	    next;
	    }
	unless ($pvsn) {
	    $fail++;
	    say RED, "  provided $m does not declare a version", RESET;
	    next;
	    }

	printf "  Expect %5s for %-32s ", $pvsn, $m;
	open my $fh, "<", $file;
	unless ($fh) {
	    $fail++;
	    say RED, "$file: $!\n", RESET;
	    next;
	    }

	my $version = extract_version ($fh);
	close $fh;
	unless ($version) {
	    $fail++;
	    say RED, "$file does not contain a VERSION", RESET;
	    next;
	    }

	if ($version ne $pvsn) {
	    $fail++;
	    say RED, "mismatch: $version", RESET;
	    next;
	    }
	say "ok";
	}

    $fail and exit 1;
    } # check_provides

sub check_changelog {
    # Check if the first date has been updated ...
    my @td = grep m/^Change(?:s|Log)$/i => glob "[Cc]*";
    unless (@td) {
	warn "No ChangeLog to check\n";
	return;
	}
    my %mnt = qw( jan 1 feb 2 mar 3 apr 4 may 5 jun 6 jul 7 aug 8 sep 9 oct 10 nov 11 dec 12 );
    open my $fh, "<", $td[0] or croak "$td[0]: $!\n";
    while (<$fh>) {
	s/\b([0-9]{4}) (?:[- ])
	    ([0-9]{1,2}) (?:[- ])
	    ([0-9]{1,2})\b/$3-$2-$1/x; # 2015-01-15 => 15-01-2015
	m/\b([0-9]{1,2}) (?:[- ])
	    ([0-9]{1,2}|[ADFJMNOSadfjmnos][acekopu][abcgilnprtvy]) (?:[- ])
	    ([0-9]{4})\b/x or next;
	my ($d, $m, $y) = ($1 + 0, ($mnt{lc $2} || $2) + 0, $3 + 0);
	printf STDERR "Most recent ChangeLog entry is dated %02d-%02d-%04d\n", $d, $m, $y;
	unless ($ENV{SKIP_CHANGELOG_DATE}) {
	    my @t = localtime;
	    my $D = Delta_Days ($y, $m , $d, $t[5] + 1900, $t[4] + 1, $t[3]);
	    $D < 0 and croak  RED,    "Last entry in $td[0] is in the future!",               RESET, "\n";
	    $D > 2 and croak  RED,    "Last entry in $td[0] is not up to date ($D days ago)", RESET, "\n";
	    $D > 0 and warn   YELLOW, "Last entry in $td[0] is not today",                    RESET, "\n";
	    }
	last;
	}
    close $fh;
    } # check_changelog

sub done_testing {
    check_changelog ();
    Test::More::done_testing ();
    } # done_testing

sub quiet {
    my $self = shift;
    @_ and $self->{quiet} = defined $_[0];
    $self->{quiet};
    } # quiet

sub print_json {
    my $self = shift;
    my $jsn = $self->{jsn} || $self->add_json ();
    print JSON::PP->new->utf8 (1)->pretty (1)->encode ($jsn);
    } # print_json

sub print_yaml {
    my $self = shift;
    print @{$self->{yml}};
    } # print_yaml

sub write_yaml {
    my ($self, $out) = @_;
    $out ||= "META.yml";
    $out =~ s/\.jso?n$/.yml/;
    open my $fh, ">", $out or croak "$out: $!\n";
    print $fh @{$self->{yml}};
    close $fh;
    $self->fix_meta ($out);
    } # print_yaml

sub add_json {
    my $self = shift;
    # Convert to meta-spec version 2
    # licenses are lists now
    my $jsn = $self->{h};
    $jsn->{"meta-spec"} = {
	version	=> "2",
	url	=> "https://metacpan.org/module/CPAN::Meta::Spec?#meta-spec",
	};
    exists $jsn->{resources}{license} and
	$jsn->{resources}{license} = [ $jsn->{resources}{license} ];
    delete $jsn->{distribution_type};
    if (exists $jsn->{license}) {
	if (ref $jsn->{license} eq "ARRAY") {
	    $jsn->{license}[0] =~ s/^perl$/perl_5/i;
	    }
	else {
	    $jsn->{license}    =~ s/^perl$/perl_5/i;
	    $jsn->{license}    = [ $jsn->{license} ];
	    }
	}
    if (exists $jsn->{resources}{bugtracker}) {
	my $url = $jsn->{resources}{bugtracker};
	$jsn->{resources}{bugtracker} = {
	    web  => $url,
	    };
	}
    if (exists $jsn->{resources}{repository}) {
	my $url = $jsn->{resources}{repository};
	my $web = $url;
	$url =~ s{repo.or.cz/w/}{repo.or.cz/r/};
	$web =~ s{repo.or.cz/r/}{repo.or.cz/w/};
	$jsn->{resources}{repository} = {
	    type => "git",
	    web  => $web,
	    url  => $url,
	    };
	}
    foreach my $sct ("", "configure_", "build_", "test_") {
	(my $x = $sct || "runtime") =~ s/_$//;
	for (qw( requires recommends suggests )) {
	    exists $jsn->{"$sct$_"} and
		$jsn->{prereqs}{$x}{$_} = delete $jsn->{"$sct$_"};
	    }
	}

    # optional features do not yet know about requires and/or recommends diirectly
    if (my $of = $jsn->{optional_features}) {
	foreach my $f (keys %$of) {
	    if (my $r = delete $of->{$f}{requires}) {
		#$jsn->{prereqs}{runtime}{recommends}{$_} //= $r->{$_} for keys %$r;
		$of->{$f}{prereqs}{runtime}{requires} = $r;
		}
	    if (my $r = delete $of->{$f}{recommends}) {
		#$jsn->{prereqs}{runtime}{recommends}{$_} //= $r->{$_} for keys %$r;
		$of->{$f}{prereqs}{runtime}{recommends} = $r;
		}
	    if (my $r = delete $of->{$f}{suggests}) {
		#$jsn->{prereqs}{runtime}{suggests}{$_} //= $r->{$_} for keys %$r;
		$of->{$f}{prereqs}{runtime}{suggests} = $r;
		}
	    }
	}

    $jsn = CPAN::Meta::Converter->new ($jsn)->convert (version => "2");
    $jsn->{generated_by} = "Author";
    $self->{jsn} = $jsn;
    } # add_json

sub fix_meta {
    my ($self, $yf) = @_;

    my $jsn = $self->add_json ();

    my $cmv = CPAN::Meta::Validator->new ($jsn);
    $cmv->is_valid or
	croak join "\n" => RED, "META Validator found fail:\n", $cmv->errors, RESET, "";

    unless ($yf) {
	my @my = grep { -s } glob ("*/META.yml"), "META.yml" or croak "No META files";
	$yf = $my[0];
	}
    my $jf = $yf =~ s/yml$/json/r;
    open my $jh, ">", $jf or croak "Cannot update $jf: $!\n";
    print   $jh JSON::PP->new->utf8 (1)->pretty (1)->encode ($jsn);
    close   $jh;

    # Now that 2.0 JSON is corrrect, create a 1.4 YAML back from the modified stuff
    my $yml = $jsn;
    # 1.4 does not know about test_*, move them to *
    if (my $tp = delete $yml->{prereqs}{test}) {
	foreach my $phase (keys %{$tp}) {
	    my $p = $tp->{$phase};
	    #DDumper { $phase => $p };
	    $yml->{prereqs}{runtime}{$phase}{$_} //= $p->{$_} for keys %{$p};
	    }
	}

    # Optional features in 1.4 knows requires, but not recommends.
    # The Lancaster Consensus moves 2.0 optional recommends promote to
    # requires in 1.4
    if (my $of = $yml->{optional_features}) {
	foreach my $f (keys %$of) {
	    if (my $r = delete $of->{$f}{prereqs}{runtime}{recommends}) {
		$of->{$f}{requires} = $r;
		}
	    if (my $r = delete $of->{$f}{prereqs}{runtime}{suggests}) {
		$of->{$f}{suggests} = $r;
		}
	    }
	}
    # runtime and test_requires are unknown as top-level in 1.4
    foreach my $phase (qw( xuntime test_requires )) {
	if (my $p = delete $yml->{$phase}) {
	    foreach my $f (keys %$p) {
		$yml->{$f}{$_} ||= $p->{$f}{$_} for keys %{$p->{$f}};
		}
	    }
	}

    #DDumper $yml;
    # This does NOT create a correct YAML id the source does not comply!
    $yml = CPAN::Meta::Converter->new ($yml)->convert (version => "1.4");
    $yml->{requires}{perl} //= $jsn->{prereqs}{runtime}{requires}{perl}
			   //  $self->{h}{requires}{perl}
			   //  "";
    $yml->{build_requires} && !keys %{$yml->{build_requires}} and
	delete $yml->{build_requires};
    #DDumper $yml;
    #exit;

    open my $my, ">", $yf or croak "Cannot update $yf: $!\n";
    print $my Dump $yml; # @{$self->{yml}};
    close $my;

    chmod 0644, glob "*/META.*";
    unlink glob "MYMETA*";
    } # fix_meta

sub _cpfd {
    my ($self, $jsn, $sct, $f) = @_;

    open my $sh, ">", \my $b;
    my $sep = "";
    for (qw( requires recommends suggests )) {
	my $x = "$sct$_";
	my $s = $jsn->{$x} or next;
	print $sh $sep;
	foreach my $m (sort keys %$s) {
	    $m eq "perl" and next;
	    my $v = $s->{$m};
	    printf $sh qq{%-10s "%s"}, $_, $m;
	    my $aw = (24 - length $m); $aw < 0 and $aw = 0;
	    printf $sh qq{%s => "%s"}, " " x $aw, $v if $v;
	    print  $sh ";";
	    if (my $i = $self->{cve_ignore}{$x}{$m}) {
		print  $sh "  # ignore : $i";
		}
	    say $sh "";
	    }
	$sep = "\n";
	}
    close $sh;
    $sct || $f and $b and $b .= "};";
    return $b;
    } # _cpfd

sub gen_cpanfile {
    my $self = shift;

    warn "Generating cpanfile ...\n";
    open my $fh, ">", "cpanfile";

    my $jsn = $self->{h};
    foreach my $sct_ ("", "configure_", "build_", "test_", "runtime_") {

	my $sct = $sct_ =~ s/_$//r;

	my $b = _cpfd ($self, $jsn, $sct_, 0) or next;

	if ($sct) {
	    say $fh qq/\non "$sct" => sub {/;
	    say $fh $b =~ s/^(?=\S)/    /gmr;
	    }
	else {
	    print $fh $b;
	    }
	}

    if (my $of = $jsn->{optional_features}) {
	foreach my $f (sort keys %$of) {
	    my $fs = $of->{$f};
	    say $fh qq/\nfeature "$f", "$fs->{description}" => sub {/;#}
	    say $fh _cpfd ($self, $fs, "", 1) =~ s/^(?=\S)/    /gmr;
	    }
	}

    close $fh;

    warn "Check CVE's ...\n";
    if (system "cpan-cve.pl", "-d", ".") {
	warn "### CVE WARNING\n";
	warn "#\n";
	warn "# The current release would have recommended versions\n";
	warn "# with known CVE's that are not (yet) ignored\n";
	sleep (5);
	}
    } # gen_cpanfile

sub security_md {
    my ($self, $update) = @_;

    my $sfn = "SECURITY.md";
    my $policy = Software::Security::Policy::Individual->new ({
        maintainer         => $self->{h}{author}[0],
        program            => $self->{name},
        timeframe          => "10 days",
        url                => $self->{h}{resources}{repository},
        perl_support_years => 5,
        });

    my $smd = $policy->fulltext;

    unless (-s $sfn) {
	open my $fh, ">:encoding(utf-8)", $sfn or die "$sfn: $! \n";
	print   $fh $smd;
	close   $fh;

	if (open $fh, "<", "MANIFEST") {
	    my @m = <$fh>;
	    close $fh;
	    unless (grep m/^$sfn(?:\s|$)/ => @m) {
		open  $fh, ">>", "MANIFEST" or die "MANIFEST: $!\n";
		say   $fh "$sfn\t\tGuide for reporting security issues";
		close $fh;
		}
	    }
	say "$sfn added";
	}

    open my $fh, "<:encoding(utf-8)", $sfn or die "$sfn: $!\n";
    my $old = do { local $/; <$fh> };
    close $fh;

    $old eq $smd and return;

    if ($update) {
	open my $fh, ">:encoding(utf-8)", $sfn or die "$sfn: $!\n";
	print   $fh $smd;
	close   $fh;
	say "$sfn updated";
	}
    else {
	say "$sfn required updates:";
	say diff \$old, \$smd;
	say "to apply, use $0 --check --update";
	}
    } # gen_security

1;
