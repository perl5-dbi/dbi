# -*- perl -*-
#
#   DBD::File - A base class for implementing DBI drivers that
#               act on plain files
#
#  This module is currently maintained by
#
#      H.Merijn Brand & Jens Rehsack
#
#  The original author is Jochen Wiedmann.
#
#  Copyright (C) 2009,2010 by H.Merijn Brand & Jens Rehsack
#  Copyright (C) 2004 by Jeff Zucker
#  Copyright (C) 1998 by Jochen Wiedmann
#
#  All rights reserved.
#
#  You may distribute this module under the terms of either the GNU
#  General Public License or the Artistic License, as specified in
#  the Perl README file.

require 5.005;

use strict;

use DBI ();
require DBI::SQL::Nano;
require File::Spec;

package DBD::File;

use strict;

use Carp;
use vars qw( @ISA $VERSION $drh $valid_attrs );

$VERSION = "0.39";

$drh = undef;		# holds driver handle(s) once initialised

sub driver ($;$)
{
    my ($class, $attr) = @_;

    # Drivers typically use a singleton object for the $drh
    # We use a hash here to have one singleton per subclass.
    # (Otherwise DBD::CSV and DBD::DBM, for example, would
    # share the same driver object which would cause problems.)
    # An alternative would be not not cache the $drh here at all
    # and require that subclasses do that. Subclasses should do
    # their own caching, so caching here just provides extra safety.
    $drh->{$class} and return $drh->{$class};

    DBI->setup_driver ("DBD::File"); # only needed once but harmless to repeat
    $attr ||= {};
    {	no strict "refs";
	unless ($attr->{Attribution}) {
	    $class eq "DBD::File" and
		$attr->{Attribution} = "$class by Jeff Zucker";
	    $attr->{Attribution} ||= ${$class . "::ATTRIBUTION"} ||
		"oops the author of $class forgot to define this";
	    }
	$attr->{Version} ||= ${$class . "::VERSION"};
	$attr->{Name} or ($attr->{Name} = $class) =~ s/^DBD\:\://;
	}

    $drh->{$class} = DBI::_new_drh ($class . "::dr", $attr);
    $drh->{$class}->STORE (ShowErrorStatement => 1);
    return $drh->{$class};
    } # driver

sub CLONE
{
    undef $drh;
    } # CLONE

# ====== DRIVER ================================================================

package DBD::File::dr;

use strict;

$DBD::File::dr::imp_data_size = 0;

sub connect ($$;$$$)
{
    my ($drh, $dbname, $user, $auth, $attr)= @_;

    # create a 'blank' dbh
    my $this = DBI::_new_dbh ($drh, {
	Name		=> $dbname,
	USER		=> $user,
	CURRENT_USER	=> $user,
	});

    if ($this) {
	# must be done first, because setting flags implicitely calls $dbdname::st->STORE
	$this->func ("init_valid_attributes");
	my ($var, $val);
	$this->{f_dir} = File::Spec->curdir ();
	while (length $dbname) {
	    if ($dbname =~ s/^((?:[^\\;]|\\.)*?);//s) {
		$var    = $1;
		}
	    else {
		$var    = $dbname;
		$dbname = "";
		}
	    if ($var =~ m/^(.+?)=(.*)/s) {
		$var = $1;
		($val = $2) =~ s/\\(.)/$1/g;
		$this->{$var} = $val;
		}
	    }
	}
    $this->STORE (Active => 1);
    $this->func ("set_versions");
    return $this;
    } # connect

sub data_sources ($;$)
{
    my ($drh, $attr) = @_;
    my $dir = $attr && exists $attr->{f_dir}
	? $attr->{f_dir}
	: File::Spec->curdir ();
    my ($dirh) = Symbol::gensym ();
    unless (opendir ($dirh, $dir)) {
	$drh->set_err ($DBI::stderr, "Cannot open directory $dir: $!");
	return;
	}

    my ($file, @dsns, %names, $driver);
    if ($drh->{ImplementorClass} =~ m/^dbd\:\:([^\:]+)\:\:/i) {
	$driver = $1;
	}
    else {
	$driver = "File";
	}

    while (defined ($file = readdir ($dirh))) {
	if ($^O eq "VMS") {
	    # if on VMS then avoid warnings from catdir if you use a file
	    # (not a dir) as the file below
	    $file !~ m/\.dir$/oi and next;
	    }
	my $d = File::Spec->catdir ($dir, $file);
	# allow current dir ... it can be a data_source too
	$file ne File::Spec->updir () && -d $d and
	    push @dsns, "DBI:$driver:f_dir=$d";
	}
    return @dsns;
    } # data_sources

sub disconnect_all
{
    } # disconnect_all

sub DESTROY
{
    undef;
    } # DESTROY

# ====== DATABASE ==============================================================

package DBD::File::db;

use strict;
use Carp;

$DBD::File::db::imp_data_size = 0;

sub ping
{
    ($_[0]->FETCH ("Active")) ? 1 : 0;
    } # ping

sub prepare ($$;@)
{
    my ($dbh, $statement, @attribs) = @_;

    # create a 'blank' sth
    my $sth = DBI::_new_sth ($dbh, {Statement => $statement});

    if ($sth) {
	my $class = $sth->FETCH ("ImplementorClass");
	$class =~ s/::st$/::Statement/;
	my $stmt;

	# if using SQL::Statement version > 1
	# cache the parser object if the DBD supports parser caching
	# SQL::Nano and older SQL::Statements don't support this

	if ( $dbh->{sql_handler} eq "SQL::Statement" and
	     $dbh->{sql_statement_version} > 1) {
	    my $parser = $dbh->{csv_sql_parser_object};
	    $parser ||= eval { $dbh->func ("cache_sql_parser_object") };
	    if ($@) {
		$stmt = eval { $class->new ($statement) };
		}
	    else {
		$stmt = eval { $class->new ($statement, $parser) };
		}
	    }
	else {
	    $stmt = eval { $class->new ($statement) };
	    }
	if ($@) {
	    $dbh->set_err ($DBI::stderr, $@);
	    undef $sth;
	    }
	else {
	    $sth->STORE ("f_stmt", $stmt);
	    $sth->STORE ("f_params", []);
	    $sth->STORE ("NUM_OF_PARAMS", scalar ($stmt->params ()));
	    }
	}
    return $sth;
    } # prepare

sub set_versions
{
    my $this = shift;
    $this->{f_version} = $DBD::File::VERSION;
    for (qw( nano_version statement_version )) {
	# strip development release version part
	($this->{"sql_$_"} = $DBI::SQL::Nano::versions->{$_} || "") =~ s/_[0-9]+$//;
	}
    $this->{sql_handler} = $this->{sql_statement_version}
	? "SQL::Statement"
	: "DBI::SQL::Nano";
    return $this;
    } # set_versions

sub init_valid_attributes
{
    my $sth = shift;

    $sth->{f_valid_attrs} = {
	f_version  => 1, # DBD::File version
	f_dir      => 1, # base directory
	f_ext      => 1, # file extension
	f_schema   => 1, # schema name
	f_tables   => 1, # base directory
	f_lock     => 1, # Table locking mode
	f_encoding => 1, # Encoding of the file
	};
    $sth->{sql_valid_attrs} = {
	sql_handler           => 1, # Nano or S:S
	sql_nano_version      => 1, # Nano version
	sql_statement_version => 1, # S:S version
	};

    return $sth;
    } # init_valid_attributes

sub cache_sql_parser_object
{
    my $dbh    = shift;
    my $parser = {
	dialect    => "CSV",
	RaiseError => $dbh->FETCH ("RaiseError"),
	PrintError => $dbh->FETCH ("PrintError"),
	};
    my $sql_flags = $dbh->FETCH ("sql_flags") || {};
    %$parser = (%$parser, %$sql_flags);
    $parser = SQL::Parser->new ($parser->{dialect}, $parser);
    $dbh->{csv_sql_parser_object} = $parser;
    return $parser;
    } # cache_sql_parser_object

sub disconnect ($)
{
    $_[0]->STORE (Active => 0);
    return 1;
    } # disconnect

sub FETCH ($$)
{
    my ($dbh, $attrib) = @_;
    $attrib eq "AutoCommit" and
	return 1;

    if ($attrib eq (lc $attrib)) {
	# Driver private attributes are lower cased

	# Error-check for valid attributes
	# not implemented yet, see STORE
	#
	return $dbh->{$attrib};
	}
    # else pass up to DBI to handle
    return $dbh->SUPER::FETCH ($attrib);
    } # FETCH

sub STORE ($$$)
{
    my ($dbh, $attrib, $value) = @_;

    if ($attrib eq "AutoCommit") {
	$value and return 1;    # is already set
	croak "Can't disable AutoCommit";
	}

    if ($attrib eq lc $attrib) {
	# Driver private attributes are lower cased

	# I'm not implementing this yet because other drivers may be
	# setting f_ and sql_ attrs I don't know about
	# I'll investigate and publicize warnings to DBD authors
	# then implement this

	# return to implementor if not f_ or sql_
	# not implemented yet
	# my $class = $dbh->FETCH ("ImplementorClass");
	#
	# !$dbh->{f_valid_attrs}{$attrib} && !$dbh->{sql_valid_attrs}{$attrib} and
	#    return $dbh->set_err ($DBI::stderr, "Invalid attribute '$attrib'");
	#  $dbh->{$attrib} = $value;

	if ($attrib eq "f_dir") {
	    -d $value or
		return $dbh->set_err ($DBI::stderr, "No such directory '$value'");
	    }
	if ($attrib eq "f_ext") {
	    $value eq "" || $value =~ m{^\.\w+(?:/[rR]*)?$} or
		carp "'$value' doesn't look like a valid file extension attribute\n";
	    }
	$dbh->{$attrib} = $value;
	return 1;
	}
    return $dbh->SUPER::STORE ($attrib, $value);
    } # STORE

sub DESTROY ($)
{
    my $dbh = shift;
    $dbh->SUPER::FETCH ("Active") and $dbh->disconnect ;
    undef $dbh->{csv_sql_parser_object};
    } # DESTROY

sub type_info_all ($)
{
    [ { TYPE_NAME          => 0,
	DATA_TYPE          => 1,
	PRECISION          => 2,
	LITERAL_PREFIX     => 3,
	LITERAL_SUFFIX     => 4,
	CREATE_PARAMS      => 5,
	NULLABLE           => 6,
	CASE_SENSITIVE     => 7,
	SEARCHABLE         => 8,
	UNSIGNED_ATTRIBUTE => 9,
	MONEY              => 10,
	AUTO_INCREMENT     => 11,
	LOCAL_TYPE_NAME    => 12,
	MINIMUM_SCALE      => 13,
	MAXIMUM_SCALE      => 14,
	},
      [ "VARCHAR",	DBI::SQL_VARCHAR (),
	undef, "'", "'", undef, 0, 1, 1, 0, 0, 0, undef, 1, 999999,
	],
      [ "CHAR",		DBI::SQL_CHAR (),
	undef, "'", "'", undef, 0, 1, 1, 0, 0, 0, undef, 1, 999999,
	],
      [ "INTEGER",	DBI::SQL_INTEGER (),
	undef, "",  "",  undef, 0, 0, 1, 0, 0, 0, undef, 0, 0,
	],
      [ "REAL",		DBI::SQL_REAL (),
	undef, "",  "",  undef, 0, 0, 1, 0, 0, 0, undef, 0, 0,
	],
      [ "BLOB",		DBI::SQL_LONGVARBINARY (),
	undef, "'", "'", undef, 0, 1, 1, 0, 0, 0, undef, 1, 999999,
	],
      [ "BLOB",		DBI::SQL_LONGVARBINARY (),
	undef, "'", "'", undef, 0, 1, 1, 0, 0, 0, undef, 1, 999999,
	],
      [ "TEXT",		DBI::SQL_LONGVARCHAR (),
	undef, "'", "'", undef, 0, 1, 1, 0, 0, 0, undef, 1, 999999,
	]];
    } # type_info_all

{   my $names = [
	qw( TABLE_QUALIFIER TABLE_OWNER TABLE_NAME TABLE_TYPE REMARKS )];

    sub table_info ($)
    {
	my $dbh  = shift;
	my $dir  = $dbh->{f_dir};
	my $dirh = Symbol::gensym ();

	unless (opendir $dirh, $dir) {
	    $dbh->set_err ($DBI::stderr, "Cannot open directory $dir: $!");
	    return;
	    }

	my $class = $dbh->FETCH ("ImplementorClass");
	$class =~ s/::db$/::Table/;
	my ($file, @tables, %names);
	my $schema = exists $dbh->{f_schema}
	    ? defined $dbh->{f_schema} && $dbh->{f_schema} ne ""
		? $dbh->{f_schema} : undef
	    : eval { getpwuid ((stat $dir)[4]) }; # XXX Win32::pwent
	while (defined ($file = readdir ($dirh))) {
	    my ($tbl, $meta) = $class->get_table_meta ($dbh, $file, 0, 0) or next; # XXX
	    $tbl && $meta && -f $meta->{f_fqfn} or next;
	    push @tables, [ undef, $schema, $tbl, "TABLE", undef ];
	    }
	unless (closedir $dirh) {
	    $dbh->set_err ($DBI::stderr, "Cannot close directory $dir: $!");
	    return;
	    }

	my $dbh2 = $dbh->{csv_sponge_driver};
	unless ($dbh2) {
	    $dbh2 = $dbh->{csv_sponge_driver} = DBI->connect ("DBI:Sponge:");
	    unless ($dbh2) {
		$dbh->set_err ($DBI::stderr, $DBI::errstr);
		return;
		}
	    }

	# Temporary kludge: DBD::Sponge dies if @tables is empty. :-(
	@tables or return;

	my $sth = $dbh2->prepare ("TABLE_INFO", {
				    rows  => \@tables,
				    NAMES => $names,
				    });
	$sth or $dbh->set_err ($DBI::stderr, $dbh2->errstr);
	return $sth;
	} # table_info
    }

sub list_tables ($)
{
    my $dbh = shift;
    my ($sth, @tables);
    $sth = $dbh->table_info () or return;
    while (my $ref = $sth->fetchrow_arrayref ()) {
	push @tables, $ref->[2];
	}
    return @tables;
    } # list_tables

sub quote ($$;$)
{
    my ($self, $str, $type) = @_;
    defined $str or return "NULL";
    defined $type && (
	    $type == DBI::SQL_NUMERIC  ()
	 || $type == DBI::SQL_DECIMAL  ()
	 || $type == DBI::SQL_INTEGER  ()
	 || $type == DBI::SQL_SMALLINT ()
	 || $type == DBI::SQL_FLOAT    ()
	 || $type == DBI::SQL_REAL     ()
	 || $type == DBI::SQL_DOUBLE   ()
	 || $type == DBI::SQL_TINYINT  ())
	and return $str;

    $str =~ s/\\/\\\\/sg;
    $str =~ s/\0/\\0/sg;
    $str =~ s/\'/\\\'/sg;
    $str =~ s/\n/\\n/sg;
    $str =~ s/\r/\\r/sg;
    return "'$str'";
    } # quote

sub commit ($)
{
    my $dbh = shift;
    $dbh->FETCH ("Warn") and
	carp "Commit ineffective while AutoCommit is on", -1;
    return 1;
    } # commit

sub rollback ($)
{
    my $dbh = shift;
    $dbh->FETCH ("Warn") and
	carp "Rollback ineffective while AutoCommit is on", -1;
    return 0;
    } # rollback

# ====== STATEMENT =============================================================

package DBD::File::st;

use strict;

$DBD::File::st::imp_data_size = 0;

sub bind_param ($$$;$)
{
    my ($sth, $pNum, $val, $attr) = @_;
    if ($attr && defined $val) {
	my $type = ref $attr eq "HASH" ? $attr->{TYPE} : $attr;
	if (   $attr == DBI::SQL_BIGINT   ()
	    || $attr == DBI::SQL_INTEGER  ()
	    || $attr == DBI::SQL_SMALLINT ()
	    || $attr == DBI::SQL_TINYINT  ()
	       ) {
	    $val += 0;
	    }
	elsif ($attr == DBI::SQL_DECIMAL ()
	    || $attr == DBI::SQL_DOUBLE  ()
	    || $attr == DBI::SQL_FLOAT   ()
	    || $attr == DBI::SQL_NUMERIC ()
	    || $attr == DBI::SQL_REAL    ()
	       ) {
	    $val += 0.;
	    }
	else {
	    $val = "$val";
	    }
	}
    $sth->{f_params}[$pNum - 1] = $val;
    return 1;
    } # bind_param

sub execute
{
    my $sth = shift;
    my $params = @_ ? ($sth->{f_params} = [ @_ ]) : $sth->{f_params};

    $sth->finish;
    my $stmt = $sth->{f_stmt};
    unless ($sth->{f_params_checked}++) {
	# bug in SQL::Statement 1.20 and below causes breakage
	# on all but the first call
	unless ((my $req_prm = $stmt->params ()) == (my $nparm = @$params)) {
	    my $msg = "You passed $nparm parameters where $req_prm required";
	    $sth->set_err ($DBI::stderr, $msg);
	    return;
	    }
	}
    my @err;
    my $result = eval {
	local $SIG{__WARN__} = sub { push @err, @_ };
	$stmt->execute ($sth, $params);
	};
    if ($@ || @err) {
	$sth->set_err ($DBI::stderr, $@ || $err[0]);
	return undef;
	}

    if ($stmt->{NUM_OF_FIELDS}) {    # is a SELECT statement
	$sth->STORE (Active => 1);
	$sth->FETCH ("NUM_OF_FIELDS") or
	    $sth->STORE ("NUM_OF_FIELDS", $stmt->{NUM_OF_FIELDS});
	}
    return $result;
    } # execute

sub finish
{
    my $sth = shift;
    $sth->SUPER::STORE (Active => 0);
    delete $sth->{f_stmt}{data};
    return 1;
    } # finish

sub fetch ($)
{
    my $sth  = shift;
    my $data = $sth->{f_stmt}{data};
    if (!$data || ref $data ne "ARRAY") {
	$sth->set_err ($DBI::stderr,
	    "Attempt to fetch row without a preceeding execute () call or from a non-SELECT statement"
	    );
	return;
	}
    my $dav = shift @$data;
    unless ($dav) {
	$sth->finish;
	return;
	}
    if ($sth->FETCH ("ChopBlanks")) {
	$_ && $_ =~ s/\s+$// for @$dav;
	}
    return $sth->_set_fbav ($dav);
    } # fetch
*fetchrow_arrayref = \&fetch;

my %unsupported_attrib = map { $_ => 1 } qw( TYPE PRECISION );

sub FETCH ($$)
{
    my ($sth, $attrib) = @_;
    exists $unsupported_attrib{$attrib}
	and return undef;    # Workaround for a bug in DBI 0.93
    $attrib eq "NAME" and
	return $sth->FETCH ("f_stmt")->{NAME};
    if ($attrib eq "NULLABLE") {
	my ($meta) = $sth->FETCH ("f_stmt")->{NAME};    # Intentional !
	$meta or return undef;
	return [ (1) x @$meta ];
	}
    if ($attrib eq lc $attrib) {
	# Private driver attributes are lower cased
	return $sth->{$attrib};
	}
    # else pass up to DBI to handle
    return $sth->SUPER::FETCH ($attrib);
    } # FETCH

sub STORE ($$$)
{
    my ($sth, $attrib, $value) = @_;
    exists $unsupported_attrib{$attrib}
	and return;    # Workaround for a bug in DBI 0.93
    if ($attrib eq lc $attrib) {
	# Private driver attributes are lower cased
	$sth->{$attrib} = $value;
	return 1;
	}
    return $sth->SUPER::STORE ($attrib, $value);
    } # STORE

sub DESTROY ($)
{
    my $sth = shift;
    $sth->SUPER::FETCH ("Active") and $sth->finish;
    undef $sth->{f_stmt};
    undef $sth->{f_params};
    } # DESTROY

sub rows ($)
{
    return $_[0]->{f_stmt}{NUM_OF_ROWS};
    } # rows

# ====== SQL::STATEMENT ========================================================

package DBD::File::Statement;

use strict;
use Carp;

# Jochen's old check for flock ()
#
# my $locking = $^O ne "MacOS"  &&
#              ($^O ne "MSWin32" || !Win32::IsWin95 ())  &&
#               $^O ne "VMS";

@DBD::File::Statement::ISA = qw( DBI::SQL::Nano::Statement );

sub open_table ($$$$$)
{
    my ($self, $data, $table, $createMode, $lockMode) = @_;

    my $class = ref $self;
    $class =~ s/::Statement/::Table/;

    my $flags = {
	createMode	=> $createMode,
	lockMode	=> $lockMode,
	};
    $self->{command} eq "DROP" and $flags->{dropMode} = 1;

    return $class->new ($data, { table => $table }, $flags);
    } # open_table

# ====== SQL::TABLE ============================================================

package DBD::File::Table;

use strict;
use Carp;
require IO::File;

# We may have a working flock () built-in but that doesn't mean that locking
# will work on NFS (flock () may hang hard)
my $locking = eval { flock STDOUT, 0; 1 };

@DBD::File::Table::ISA = qw(DBI::SQL::Nano::Table);

# ====== FLYWEIGHT SUPPORT =====================================================

# Flyweight support for table_info
# The functions file2table, init_table_meta, default_table_meta and
# get_table_meta are using $self arguments for polymorphism only. The
# must not rely on an instantiated DBD::File::Table
sub file2table
{
    my ($self, $meta, $file, $file_is_table, $quoted) = @_;

    $file eq "." || $file eq ".."	and return;

    my ($ext, $req) = ("", 0); # XXX
    if ($meta->{f_ext}) {
	($ext, my $opt) = split m/\//, $meta->{f_ext};
	if ($ext && $opt) {
	    $opt =~ m/r/i and $req = 1;
	    }
	}

    (my $tbl = $file) =~ s/$ext$//i;
    $file_is_table and $file = "$tbl$ext";

    # Fully Qualified File Name
    unless ($quoted) { # table names are case insensitive in SQL
	my $dir = $meta->{f_dir};
	opendir my $dh, $dir or croak "Can't open '$dir': $!";
	my @f = grep { lc $_ eq lc $file } readdir $dh;
	@f == 1 and $tbl = $file = $f[0];
	$tbl =~ s/$ext$//i; # XXX /i flag only when not quoted?
	closedir $dh or croak "Can't close '$dir': $!";
	}
    my $fqfn = File::Spec->catfile ($meta->{f_dir}, $file);
    my $fqbn = File::Spec->catfile ($meta->{f_dir}, $tbl);

    $file = $fqfn;
    if ($ext) {
	if ($req) {
	    # File extension required
	    $file =~ s/$ext$//i			or  return;
	    }
	else {
	    # File extension optional, skip if file with extension exists
	    grep m/$ext$/i, glob "$fqfn.*"	and return;
	    $file =~ s/$ext$//i;
	    }
	}

    $meta->{f_fqfn} = $fqfn;
    $meta->{f_fqbn} = $file;
    !defined ($meta->{f_lockfile}) && $meta->{f_lockfile} and
	$meta->{f_fqln} = $meta->{f_fqbn} . $meta->{f_lockfile};

    return $tbl;
    } # file2table

my $open_table_re = sprintf "(?:%s|%s|%s)",
    quotemeta (File::Spec->curdir  ()),
    quotemeta (File::Spec->updir   ()),
    quotemeta (File::Spec->rootdir ());

sub init_table_meta ($$$$$)
{
    my ($self, $dbh, $table, $file_is_table, $quoted) = @_;

    defined $dbh->{f_meta}{$table} and "HASH" eq ref $dbh->{f_meta}{$table} or
        $dbh->{f_meta}{$table} = {};
    my $meta = $dbh->{f_meta}{$table};
    exists  $meta->{f_dir}	or $meta->{f_dir}	= $dbh->{f_dir};
    defined $meta->{f_ext}	or $meta->{f_ext}	= $dbh->{f_ext};
    defined $meta->{f_encoding}	or $meta->{f_encoding}	= $dbh->{f_encoding};
    exists  $meta->{f_lock}	or $meta->{f_lock}	= $dbh->{f_lock};
    exists  $meta->{f_lockfile}	or $meta->{f_lockfile}	= $dbh->{f_lockfile};
    defined $meta->{f_schema}	or $meta->{f_schema}	= $dbh->{f_schema};
    unless (defined $meta->{f_fqfn}) {
	my $tbl = $self->file2table ($meta, $table, $file_is_table, $quoted);
	$tbl or $meta->{f_fqfn}	= undef;
	}
    } # init_table_meta

sub default_table_meta ($$$)
{
    my ($self, $dbh, $table) = @_;
    my $meta = { f_fqfn => $table, f_fqbn => $table };
    return $meta;
    } # init_table_meta

sub get_table_meta ($$$$;$)
{
    my ($self, $dbh, $table, $file_is_table, $quoted) = @_;
    unless (defined $quoted) {
	$quoted = 0;
	$table =~ s/^\"// and $quoted = 1;    # handle quoted identifiers
	$table =~ s/\"$//;
	}

    my $meta;
    if (    $table !~ m/^$open_table_re/o
	and $table !~ m{^[/\\]}      # root
	and $table !~ m{^[a-z]\:}    # drive letter
	) {
	# should be done anyway, table_info might generate incomplete f_meta
	$self->init_table_meta ($dbh, $table, $file_is_table, $quoted);
	$meta = $dbh->{f_meta}->{$table};
	}
    else {
	$meta = $self->default_table_meta ($dbh, $table);
	}

    return ($table, $meta);
    } # get_table_meta

# ====== FILE OPEN =============================================================

sub open_file ($$$)
{
    my ($self, $meta, $attrs, $flags) = @_;

    defined $meta->{f_fqfn} && $meta->{f_fqfn} ne "" or croak "No filename given";

    my ($fh, $fn);
    unless ($meta->{f_dontopen}) {
	$fn = $meta->{f_fqfn};
	if ($flags->{createMode}) {
	    -f $meta->{f_fqfn} and
		croak "Cannot create table $attrs->{table}: Already exists";
	    $fh = IO::File->new ($fn, "a+") or
		croak "Cannot open $fn for writing: $!";
	    $fh->seek (0, 0) or
		croak "Error while seeking back: $!";
	    }
	else {
	    unless ($fh = IO::File->new ($fn, ($flags->{lockMode} ? "r+" : "r"))) {
		croak "Cannot open $fn: $!";
		}
	    }

	if ($fh) {
	    if (my $enc = $meta->{f_encoding}) {
		binmode $fh, ":encoding($enc)" or
		    croak "Failed to set encoding layer '$enc' on $fn: $!";
		}
	    else {
		binmode $fh or croak "Failed to set binary mode on $fn: $!";
		}
	    }

	$meta->{fh} = $fh;
	}
    if ($meta->{f_fqln}) {
	$fn = $meta->{f_fqln};
	if ($flags->{createMode}) {
	    -f $fn and
		croak "Cannot create table lock for $attrs->{table}: Already exists";
	    $fh = IO::File->new ($fn, "a+") or
		croak "Cannot open $fn for writing: $!";
	    }
	else {
	    unless ($fh = IO::File->new ($fn, ($flags->{lockMode} ? "r+" : "r"))) {
		croak "Cannot open $fn: $!";
		}
	    }

	$meta->{lockfh} = $fh;
	}

    if ($locking && $fh) {
	my $lm = defined $flags->{f_lock}
		      && $flags->{f_lock} =~ m/^[012]$/
		       ? $flags->{f_lock}
		       : $flags->{lockMode} ? 2 : 1;
	if ($lm == 2) {
	    flock $fh, 2 or croak "Cannot obtain exclusive lock on $fn: $!";
	    }
	elsif ($lm == 1) {
	    flock $fh, 1 or croak "Cannot obtain shared lock on $fn: $!";
	    }
	# $lm = 0 is forced no locking at all
	}
    } # open_file

# ====== SQL::Eval API =========================================================

sub new
{
    my ($className, $data, $attrs, $flags) = @_;
    my $dbh = $data->{Database};

    my $meta;
    ($attrs->{table}, $meta) = $className->get_table_meta ($dbh, $attrs->{table}, 1);

    $className->open_file ($meta, $attrs, $flags);

    my $columns = {};
    my $array   = [];
    my $tbl     = {
	%{$attrs},
	meta          => $meta,
	col_names     => $meta->{col_names} || [],
	};
    return $className->SUPER::new ($tbl);
    } # new

sub drop ($)
{
    my ($self, $data) = @_;
    my $meta = $self->{meta};
    # We have to close the file before unlinking it: Some OS'es will
    # refuse the unlink otherwise.
    $meta->{fh} and $meta->{fh}->close ();
    $meta->{lockfh} and $meta->{lockfh}->close ();
    undef $meta->{fh};
    undef $meta->{lockfh};
    $meta->{f_fqfn} and unlink $meta->{f_fqfn};
    $meta->{f_fqln} and unlink $meta->{f_fqln};
    delete $data->{Database}->{f_meta}->{$self->{table}};
    return 1;
    } # drop

sub seek ($$$$)
{
    my ($self, $data, $pos, $whence) = @_;
    my $meta = $self->{meta};
    if ($whence == 0 && $pos == 0) {
	$pos = defined $meta->{first_row_pos} ? $meta->{first_row_pos} : 0;
	}
    elsif ($whence != 2 || $pos != 0) {
	croak "Illegal seek position: pos = $pos, whence = $whence";
	}

    $meta->{fh}->seek ($pos, $whence) or
	croak "Error while seeking in " . $meta->{f_fqfn} . ": $!";
    } # seek

sub truncate ($$)
{
    my ($self, $data) = @_;
    my $meta = $self->{meta};
    $meta->{fh}->truncate ($meta->{fh}->tell ()) or
	croak "Error while truncating " . $meta->{f_fqfn} . ": $!";
    return 1;
    } # truncate

sub DESTROY
{
    my $self = shift;
    my $meta = $self->{meta};
    $meta->{fh} and $meta->{fh}->close ();
    $meta->{lockfh} and $meta->{lockfh}->close ();
    undef $meta->{fh};
    undef $meta->{lockfh};
    } # DESTROY

1;

__END__

=head1 NAME

DBD::File - Base class for writing DBI drivers

=head1 SYNOPSIS

 This module is a base class for writing other DBDs.
 It is not intended to function as a DBD itself.
 If you want to access flatfiles, use DBD::AnyData, or DBD::CSV,
 (both of which are subclasses of DBD::File).

=head1 DESCRIPTION

The DBD::File module is not a true DBI driver, but an abstract
base class for deriving concrete DBI drivers from it. The implication is,
that these drivers work with plain files, for example CSV files or
INI files. The module is based on the SQL::Statement module, a simple
SQL engine.

See L<DBI> for details on DBI, L<SQL::Statement> for details on
SQL::Statement and L<DBD::CSV>, L<DBD::DBM> or L<DBD::AnyData> for example
drivers.

=head2 Metadata

The following attributes are handled by DBI itself and not by DBD::File,
thus they all work like expected:

    Active
    ActiveKids
    CachedKids
    CompatMode             (Not used)
    InactiveDestroy
    Kids
    PrintError
    RaiseError
    Warn                   (Not used)

The following DBI attributes are handled by DBD::File:

=over 4

=item AutoCommit

Always on

=item ChopBlanks

Works

=item NUM_OF_FIELDS

Valid after C<< $sth->execute >>

=item NUM_OF_PARAMS

Valid after C<< $sth->prepare >>

=item NAME

Valid after C<< $sth->execute >>; undef for Non-Select statements.

=item NULLABLE

Not really working, always returns an array ref of one's, as DBD::CSV
doesn't verify input data. Valid after C<< $sth->execute >>; undef for
Non-Select statements.

=back

These attributes and methods are not supported:

    bind_param_inout
    CursorName
    LongReadLen
    LongTruncOk

In addition to the DBI attributes, you can use the following dbh
attributes:

=over 4

=item f_dir

This attribute is used for setting the directory where the files are
opened and it defaults to the current directory ("."). Usually you set
it on the dbh but it may be overridden on the statement handle.
See L<BUGS AND LIMITATIONS>.

=item f_ext

This attribute is used for setting the file extension. The format is:

  extension{/flag}

where the /flag is optional and the extension is case-insensitive.
C<f_ext> allows you to specify an extension which:

 o makes DBD::File prefer F<table.extension> over F<table>.
 o makes the table name the filename minus the extension.

    DBI:CSV:f_dir=data;f_ext=.csv

In the above example and when C<f_dir> contains both F<table.csv> and
F<table>, DBD::File will open F<table.csv> and the table will be
named "table". If F<table.csv> does not exist but F<table> does
that file is opened and the table is also called "table".

If C<f_ext> is not specified and F<table.csv> exists it will be opened
and the table will be called "table.csv" which is probably not what
you want.

NOTE: even though extensions are case-insensitive, table names are
not.

    DBI:CSV:f_dir=data;f_ext=.csv/r

The C<r> flag means the file extension is required and any filename
that does not match the extension is ignored.

=item f_schema

This will set the schema name and defaults to the owner of the
directory in which the table file resides. You can set C<f_schema> to
C<undef>.

    my $dbh = DBI->connect ("dbi:CSV:", "", "", {
        f_schema => undef,
        f_dir    => "data",
        f_ext    => ".csv/r",
        }) or die $DBI::errstr;

By setting the schema you effect the results from the tables call:

    my @tables = $dbh->tables ();

    # no f_schema
    "merijn".foo
    "merijn".bar

    # f_schema => "dbi"
    "dbi".foo
    "dbi".bar

    # f_schema => undef
    foo
    bar

Defining f_schema to the empty string is equal to setting it to C<undef>
so the DSN can be C<dbi:CSV:f_schema=;f_dir=.>.

=item f_lock

The C<f_lock> attribute is used to set the locking mode on the opened
table files. Note that not all platforms support locking.  By default,
tables are opened with a shared lock for reading, and with an
exclusive lock for writing. The supported modes are:

=over 2

=item 0

No locking at all.

=item 1

Shared locks will be used.

=item 2

Exclusive locks will be used.

=back

But see L</"KNOWN BUGS"> below.

=item f_lockfile

If you wish to use a lockfile extension other than '.lck', simply specify
the f_lockfile attribute:

  $dbh = DBI->connect('dbi:DBM:f_lockfile=.foo');
  $dbh->{f_lockfile} = '.foo';
  $dbh->{f_meta}->{qux}->{f_lockfile} = '.foo';

If you wish to disable locking, set the f_lockfile equal to 0.

  $dbh = DBI->connect('dbi:DBM:f_lockfile=0');
  $dbh->{f_lockfile} = 0;
  $dbh->{f_meta}->{qux}->{f_lockfile} = 0;

=item f_encoding

With this attribute, you can set the encoding in which the file is opened.
This is implemented using C<binmode $fh, ":encoding(<f_encoding>)">.

=item f_meta

Private data area which contains information about the tables this
module handles. Meta data of a table might not be available unless the
table has been accessed first time doing a statement on it. But it's
possible to pre-initialize attributes for each table wanted to use.

DBD::File recognizes the (public) attributes f_ext, f_dir, f_encoding, f_lock,
and f_lockfile. Be very careful when modifying attributes you do not know,
the consequence might be a destroyed table.

=back

Internally private attributes to deal with SQL backends:

=over 4

=item sql_nano_version

Contains the version of loaded DBI::SQL::Nano

=item sql_statement_version

Contains the version of loaded SQL::Statement

=item sql_handler

Contains either 'SQL::Statement' or 'DBI::SQL::Nano'.

=item sql_ram_tables

Contains optionally temporary tables.

=back

Do not modify any of above private attributes unless you understand
the implications of doing so. The behavior of DBD::File and derived
DBD's might be unpredictable when one or more of those attributes are
modified.

=head2 Driver private methods

=over 4

=item data_sources

The C<data_sources> method returns a list of subdirectories of the current
directory in the form "DBI:CSV:f_dir=$dirname".

If you want to read the subdirectories of another directory, use

    my ($drh) = DBI->install_driver ("CSV");
    my (@list) = $drh->data_sources (f_dir => "/usr/local/csv_data" );

=item list_tables

This method returns a list of file names inside $dbh->{f_dir}.
Example:

    my ($dbh) = DBI->connect ("DBI:CSV:f_dir=/usr/local/csv_data");
    my (@list) = $dbh->func ("list_tables");

Note that the list includes all files contained in the directory, even
those that have non-valid table names, from the view of SQL.

=back

=head1 SQL ENGINES

DBD::File currently supports two SQL engines: L<DBI::SQL::Nano> and
L<SQL::Statement>. DBI::SQL::Nano supports a I<very> limited subset of
SQL statements, but it might be faster for some very simple
tasks. SQL::Statement in contrast supports a much larger subset of
ANSI SQL.

To use SQL::Statement, the module version 1.28 of SQL::Statement is
a prerequisite and the environment variable C<< DBI_SQL_NANO >> must
not be set to a true value.

=head1 KNOWN BUGS AND LIMITATIONS

=over 4

=item *

This module uses flock() internally but flock is not available on all
platforms. On MacOS and Windows 95 there is no locking at all (perhaps
not so important on MacOS and Windows 95, as there is only a single
user).

=item *

The module stores details about the handled tables in a private area
of the driver handle (C<< $drh >>). This data area isn't shared between
different driver instances, so several C<< DBI->connect() >> calls will
cause different table instances and private data areas.

This data area is filled for the first time when a table is accessed,
either via an SQL statement or via C<< table_info >> and is not
destroyed when the table is dropped or the driver handle is released.

Following attributes are preserved in the data area and will evaluated
instead of driver globals:

=over 8

=item f_ext

=item f_dir

=item f_lock

=item f_lockfile

=back

For DBD::CSV tables this means, once opened 'foo.csv' as table named 'foo',
another table named 'foo' accessing the file 'foo.csl' cannot be opened.
Accessing 'foo' will always access the file 'foo.csv' in memorized
C<< f_dir >>, locking C<< f_lockfile >> via memorized C<< f_lock >>.

=item *

When used with SQL::Statement and the feature of temporary tables is
used with

  CREATE TEMP TABLE ...

the table data processing passes DBD::File::Table. No file system calls
will be made, no influence with existing (file based) tables with the same
name will occur. Temporary tables are chosen in favor over file tables,
but they will not covered by C<< table_info >>.

=back

=head1 AUTHOR

This module is currently maintained by

H.Merijn Brand < h.m.brand at xs4all.nl > and
Jens Rehsack  < rehsack at googlemail.com >

The original author is Jochen Wiedmann.

=head1 COPYRIGHT AND LICENSE

 Copyright (C) 2009-2010 by H.Merijn Brand & Jens Rehsack
 Copyright (C) 2004-2009 by Jeff Zucker
 Copyright (C) 1998-2004 by Jochen Wiedmann

All rights reserved.

You may freely distribute and/or modify this module under the terms of
either the GNU General Public License (GPL) or the Artistic License, as
specified in the Perl README file.

=head1 SEE ALSO

L<DBI>, L<DBD::DBM>, L<DBD::CSV>, L<Text::CSV>, L<Text::CSV_XS>,
L<SQL::Statement>, L<DBI::SQL::Nano>

=cut
