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

package DBD::File;

use strict;

use Carp;
use vars qw( @ISA $VERSION $drh );

$VERSION = "0.39";

$drh = undef;		# holds driver handle(s) once initialized

DBI->setup_driver ("DBD::File"); # only needed once but harmless to repeat

my %accessors = (
    versions   => "get_versions",
    get_meta   => "get_file_meta",
    set_meta   => "set_file_meta",
    clear_meta => "clear_file_meta",
    );

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

    my $prefix = DBI->driver_prefix ($class);
    my $dbclass = $class . "::db";
    while (my ($accessor, $funcname) = each %accessors) {
	my $method = $prefix . $accessor;
	$dbclass->can ($method) and next;
	my $inject = sprintf <<'EOI', $dbclass, $method, $dbclass, $funcname;
sub %s::%s
{
    my $func = %s->can (q{%s});
    goto &$func;
    }
EOI
	eval $inject;
	$dbclass->install_method ($method);
	}

    # XXX inject DBD::XXX::Statement unless exists

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
	# must be done first, because setting flags implicitly calls $dbdname::db->STORE
	$this->func ("init_default_attributes");

	my ($var, $val);
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
	    elsif ($var =~ m/^(.+?)=>(.*)/s) {
		$var = $1;
		($val = $2) =~ s/\\(.)/$1/g;
		my $ref = eval $val;
		$this->$var ($ref);
		}
	    }

	$this->STORE (Active => 1);
	}

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
require File::Spec;
require Cwd;
use Scalar::Util qw(refaddr); # in CORE since 5.7.3

if (eval { require Clone; }) {
    Clone->import ("clone");
    }
else {
    require Storable; # in CORE since 5.7.3
    *clone = \&Storable::dclone;
    }

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
	    my $parser = $dbh->{sql_parser_object};
	    $parser ||= eval { $dbh->func ("sql_parser_object") };
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
    my $dbh = shift;
    $dbh->{f_version} = $DBD::File::VERSION;
    for (qw( nano_version statement_version )) {
	# strip development release version part
	($dbh->{"sql_$_"} = $DBI::SQL::Nano::versions->{$_} || "") =~ s/_[0-9]+$//;
	}
    $dbh->{sql_handler} = $dbh->{sql_statement_version}
	? "SQL::Statement"
	: "DBI::SQL::Nano";

    return $dbh;
    } # set_versions

sub init_valid_attributes
{
    my $dbh = shift;

    $dbh->{f_valid_attrs} = {
	f_version        => 1, # DBD::File version
	f_dir            => 1, # base directory
	f_ext            => 1, # file extension
	f_schema         => 1, # schema name
	f_meta           => 1, # meta data for tables
	f_meta_map       => 1, # mapping table for identifier case
	f_lock           => 1, # Table locking mode
	f_lockfile       => 1, # Table lockfile extension
	f_encoding       => 1, # Encoding of the file
	f_valid_attrs    => 1, # File valid attributes
	f_readonly_attrs => 1, # File readonly attributes
	};
    $dbh->{sql_valid_attrs} = {
	sql_handler                => 1, # Nano or S:S
	sql_nano_version           => 1, # Nano version
	sql_statement_version      => 1, # S:S version
	sql_flags                  => 1, # flags for SQL::Parser
	sql_quoted_identifier_case => 1, # case for quoted identifiers
	sql_identifier_case        => 1, # case for non-quoted identifiers
	sql_parser_object          => 1, # SQL::Parser instance
	sql_valid_attrs            => 1, # SQL valid attributes
	sql_readonly_attrs         => 1, # SQL readonly attributes
	};
    $dbh->{f_readonly_attrs} = {
	f_version        => 1, # DBD::File version
	f_valid_attrs    => 1, # File valid attributes
	f_readonly_attrs => 1, # File readonly attributes
	};
    $dbh->{sql_readonly_attrs} = {
	sql_handler                => 1, # Nano or S:S
	sql_nano_version           => 1, # Nano version
	sql_statement_version      => 1, # S:S version
	sql_quoted_identifier_case => 1, # case for quoted identifiers
	sql_parser_object          => 1, # SQL::Parser instance
	sql_valid_attrs            => 1, # SQL valid attributes
	sql_readonly_attrs         => 1, # SQL readonly attributes
	};

    return $dbh;
    } # init_valid_attributes

sub init_default_attributes
{
    my $dbh = shift;

    # must be done first, because setting flags implicitly calls $dbdname::db->STORE
    $dbh->func ("init_valid_attributes");

    $dbh->func ("set_versions");

    # f_ext should not be initialized
    # f_map is deprecated (but might return)
    $dbh->{f_dir}      = Cwd::abs_path (File::Spec->curdir ());
    $dbh->{f_meta}     = {};
    $dbh->{f_meta_map} = {}; # choose new name because it contains other keys

    $dbh->{sql_identifier_case}        = 2; # SQL_IC_LOWER
    $dbh->{sql_quoted_identifier_case} = 3; # SQL_IC_SENSITIVE

    # complete derived attributes, if required
    (my $drv_class = $dbh->{ImplementorClass}) =~ s/::db$//;
    my $drv_prefix = DBI->driver_prefix ($drv_class);
    my $valid_attrs = $drv_prefix . "valid_attrs";
    my $ro_attrs = $drv_prefix . "readonly_attrs";

    my @comp_attrs = qw(valid_attrs version readonly_attrs);
    if (exists $dbh->{$drv_prefix . "meta"}) {
	my $attr = $dbh->{$drv_prefix . "meta"};
	defined $attr and defined $dbh->{$valid_attrs} and !defined $dbh->{$valid_attrs}{$attr} and
	    $dbh->{$valid_attrs}{$attr} = 1;

	my %h;
	tie %h, "DBD::File::TieTables", $dbh;
	$dbh->{$attr} = \%h;

        push @comp_attrs, "meta";
	}

    foreach my $comp_attr (@comp_attrs) {
	my $attr = $drv_prefix . $comp_attr;
	defined $dbh->{$valid_attrs} and !defined $dbh->{$valid_attrs}{$attr} and
	    $dbh->{$valid_attrs}{$attr} = 1;
	defined $dbh->{$ro_attrs} and !defined $dbh->{$ro_attrs}{$attr} and
	    $dbh->{$ro_attrs}{$attr} = 1;
	}

    return $dbh;
    } # init_default_attributes

sub sql_parser_object
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
    $dbh->{sql_parser_object} = $parser;
    return $parser;
    } # cache_sql_parser_object

sub disconnect ($)
{
    $_[0]->STORE (Active => 0);
    %{$_[0]->{f_meta}} = ();
    return 1;
    } # disconnect

sub FETCH ($$)
{
    my ($dbh, $attrib) = @_;
    $attrib eq "AutoCommit" and
	return 1;

    if ($attrib eq (lc $attrib)) {
	# Driver private attributes are lower cased

	# XXX Error-check for valid attributes
	# not implemented yet, see STORE
	#
	# XXX return cloned value when readonly attr
	# and not scalar type
	# use: *clone = $haveClone ? \&Clone::clone : \&Storable::dclone;
	#
	my $attr_prefix;
	$attrib =~ m/^([a-z]+_)/ and $attr_prefix = $1;
	unless ($attr_prefix) {
	    (my $drv_class = $dbh->{ImplementorClass}) =~ s/::db$//;
	    $attr_prefix = DBI->driver_prefix ($drv_class);
	    $attrib = $attr_prefix . $attrib;
	    }
	my $valid_attrs = $attr_prefix . "valid_attrs";
	my $ro_attrs = $attr_prefix . "readonly_attrs";
	exists $dbh->{$valid_attrs} and ($dbh->{$valid_attrs}{$attrib} or
	   return $dbh->set_err ($DBI::stderr, "Invalid attribute '$attrib'"));
	exists $dbh->{$ro_attrs} and $dbh->{$ro_attrs}{$attrib} and
	    defined $dbh->{$attrib} and refaddr ($dbh->{$attrib}) and
	    return clone ($dbh->{$attrib});

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
	my $attr_prefix;
	$attrib =~ m/^([a-z]+_)/ and $attr_prefix = $1;
	unless ($attr_prefix) {
	    (my $drv_class = $dbh->{ImplementorClass}) =~ s/::db$//;
	    $attr_prefix = DBI->driver_prefix ($drv_class);
	    $attrib = $attr_prefix . $attrib;
	    }
	my $valid_attrs = $attr_prefix . "valid_attrs";
	my $ro_attrs = $attr_prefix . "readonly_attrs";
	exists $dbh->{$valid_attrs} and ($dbh->{$valid_attrs}{$attrib} or
	   return $dbh->set_err ($DBI::stderr, "Invalid attribute '$attrib'"));
	exists $dbh->{$ro_attrs} and $dbh->{$ro_attrs}{$attrib} and defined $dbh->{$attrib} and
	   return $dbh->set_err ($DBI::stderr, "attribute '$attrib' is readonly and must not be modified");
	#  $dbh->{$attrib} = $value;

	if ($attrib eq "f_dir") {
	    -d $value or
		return $dbh->set_err ($DBI::stderr, "No such directory '$value'");
	    File::Spec->file_name_is_absolute ($value) or
	        $value = Cwd::abs_path ($value);
	    }

	if ($attrib eq "f_ext") {
	    $value eq "" || $value =~ m{^\.\w+(?:/[rR]*)?$} or
		carp "'$value' doesn't look like a valid file extension attribute\n";
	    }

	if (    $attrib eq "sql_identifier_case" ||
	        $attrib eq "sql_quoted_identifier_case"
	    and
		$value < 1 || $value > 4) {
	    croak "attribute '$attrib' must have a value from 1 .. 4 (SQL_IC_UPPER .. SQL_IC_MIXED)";
	    # XXX correctly a remap of all entries in f_meta/f_meta_map is required here
	    }

        # if (($attrib =~ m/^f_/   && $dbh->{f_readonly_attrs}{$attrib} or
        #      $attrib =~ m/^sql_/ && $dbh->{sql_readonly_attrs}{$attrib}) and
	#      defined $dbh->{$attrib}) {
	#     croak "attribute '$attrib' is readonly and must not be modified";
	#     }

	$dbh->{$attrib} = $value;
	return 1;
	}

    return $dbh->SUPER::STORE ($attrib, $value);
    } # STORE

sub get_versions
{
    my ($dbh, $table) = @_;
    my %vsn = (
	OS		=> "$^O ($Config::Config{osvers})",
	Perl		=> "$] ($Config::Config{archname})",
	DBI		=> $DBI::VERSION,
	);
    my %vmp;

    my $dbd_file_verinfo = join " ",
	$dbh->{f_version}, "using", $dbh->{sql_handler},
	$dbh->{sql_handler} eq "SQL::Statement"
	    ? $dbh->{sql_statement_version}
	    : $dbh->{sql_nano_version};

    (my $drv_class = $dbh->{ImplementorClass}) =~ s/::db$//;
    my $drv_prefix = DBI->driver_prefix ($drv_class);
    my $ddgv = $dbh->{ImplementorClass}->can( "get_" . $drv_prefix . "versions" );
    if ($ddgv) {
	$vsn{"DBD::File"} = $dbd_file_verinfo;
	$vmp{"DBD::File"} = "  DBD::File";
	$vsn{$drv_class}  = &$ddgv ($dbh, $table);
	}
    else {
	$vsn{"DBD::File"} = $dbd_file_verinfo;
	}

    $DBI::PurePerl and $vsn{"DBI::PurePerl"} = $DBI::PurePerl::VERSION;

    my @versions = map { sprintf "%-16s %s", $vmp{$_} || $_, $vsn{$_} }
		   sort
		   {
		       $a->isa ($b) and return -1;
		       $b->isa ($a) and return 1;
		       return $a cmp $b;
		       } keys %vsn;

    return wantarray ? @versions : join "\n", @versions;
    } # get_versions

sub get_single_table_meta
{
    my ($dbh, $table, $attr) = @_;
    my $meta;

    $table eq "." and
	return $dbh->FETCH ($attr);

    my $class = $dbh->FETCH ("ImplementorClass");
    $class =~ s/::db$/::Table/;
    (undef, $meta) = $class->get_table_meta ($dbh, $table, 1);
    $meta or croak "No such table '$table'";

    # prevent creation of undef attributes
    return $class->get_table_meta_attr ($meta, $attr);
    } # get_single_table_meta

sub get_file_meta
{
    my ($dbh, $table, $attr) = @_;

    my $gstm = $dbh->{ImplementorClass}->can ("get_single_table_meta");

    $table eq "*" and
	$table = [ ".", keys %{$dbh->{f_meta}} ];
    $table eq "+" and
	$table = [ grep { m/^[_A-Za-z0-9]+$/ } keys %{$dbh->{f_meta}} ];
    ref ($table) eq "Regexp" and
	$table = [ grep { $_ =~ $table } keys %{$dbh->{f_meta}} ];

    unless (ref ($table) or ref ($attr)) {
	return &$gstm ($dbh, $table, $attr);
	}
    else {
	ref $table or $table = [ $table ];
	ref $attr or $attr = [ $attr ];
	"ARRAY" eq ref $table or
	    croak "Invalid argument for \$table - SCALAR, Regexp or ARRAY expected but got " . ref $table;
	"ARRAY" eq ref $attr or
	    croak "Invalid argument for \$attr - SCALAR or ARRAY expected but got " . ref $attr;

	my %results;
	foreach my $tname (@{$table}) {
	    my %tattrs;
	    foreach my $aname (@{$attr}) {
		$tattrs{$aname} = &$gstm ($dbh, $tname, $aname);
		}
		$results{$tname} = \%tattrs;
	    }

	return \%results;
	}
    } # get_file_meta

sub set_single_table_meta
{
    my ($dbh, $table, $attr, $value) = @_;
    my $meta;

    $table eq "." and
	return $dbh->STORE ($attr, $value);

    my $class = $dbh->FETCH ("ImplementorClass");
    $class =~ s/::db$/::Table/;
    (undef, $meta) = $class->get_table_meta ($dbh, $table, 1);
    $meta or croak "No such table '$table'";
    $class->set_table_meta_attr ($meta, $attr, $value);

    return $dbh;
    } # set_single_table_meta

sub set_file_meta
{
    my ($dbh, $table, $attr, $value) = @_;

    my $sstm = $dbh->{ImplementorClass}->can ("set_single_table_meta");

    $table eq "*" and
	$table = [ ".", keys %{$dbh->{f_meta}} ];
    $table eq "+" and
	$table = [ grep { m/^[_A-Za-z0-9]+$/ } keys %{$dbh->{f_meta}} ];
    ref ($table) eq "Regexp" and
	$table = [ grep { $_ =~ $table } keys %{$dbh->{f_meta}} ];

    unless (ref ($table) or ref ($attr)) {
	return &$sstm ($dbh, $table, $attr, $value);
	}
    else {
	ref $table or $table = [ $table ];
	ref $attr or $attr = { $attr => $value };
	"ARRAY" eq ref $table or
	    croak "Invalid argument for \$table - SCALAR, Regexp or ARRAY expected but got " . ref $table;
	"HASH" eq ref $attr or
	    croak "Invalid argument for \$attr - SCALAR or HASH expected but got " . ref $attr;

	foreach my $tname (@{$table}) {
	    my %tattrs;
	    while (my ($aname, $aval) = each %$attr) {
		&$sstm ($dbh, $tname, $aname, $aval);
		}
	    }

	return $dbh;
	}
    } # set_file_meta

sub clear_file_meta
{
    my ($dbh, $table) = @_;

    my $class = $dbh->FETCH ("ImplementorClass");
    $class =~ s/::db$/::Table/;
    my (undef, $meta) = $class->get_table_meta ($dbh, $table, 1);
    $meta and %{$meta} = ();

    return;
    } # clear_file_meta

sub DESTROY ($)
{
    my $dbh = shift;
    $dbh->SUPER::FETCH ("Active") and $dbh->disconnect ;
    undef $dbh->{sql_parser_object};
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
	my %seen;
	while (defined ($file = readdir ($dirh))) {
	    my ($tbl, $meta) = $class->get_table_meta ($dbh, $file, 0, 0) or next; # XXX
	    # $tbl && $meta && -f $meta->{f_fqfn} or next;
	    $seen{defined $schema ? $schema : "\0"}{$tbl}++ or
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

# ====== Tie-Meta ==============================================================

package DBD::File::TieMeta;

use Carp qw(croak);
require Tie::Hash;
@DBD::File::TieMeta::ISA = qw(Tie::Hash);

sub TIEHASH
{
    my ($class, $tblClass, $tblMeta) = @_;

    my $self = bless ({ tblClass => $tblClass, tblMeta => $tblMeta, }, $class);
    return $self;
    } # new

sub STORE
{
    my ($self, $meta_attr, $meta_val) = @_;

    $self->{tblClass}->set_table_meta_attr ($self->{tblMeta}, $meta_attr, $meta_val);

    return;
    } # STORE

sub FETCH
{
    my ($self, $meta_attr) = @_;

    return $self->{tblClass}->get_table_meta_attr ($self->{tblMeta}, $meta_attr);
    } # FETCH

sub FIRSTKEY
{
    my $a = scalar keys %{$_[0]->{tblMeta}};
    each %{$_[0]->{tblMeta}};
    } # FIRSTKEY

sub NEXTKEY
{
    each %{$_[0]->{tblMeta}};
    } # NEXTKEY

sub EXISTS
{
    exists $_[0]->{tblMeta}{$_[1]};
    } # EXISTS

sub DELETE
{
    croak "Can't delete single attributes from table meta structure";
    } # DELETE

sub CLEAR
{
    %{$_[0]->{tblMeta}} = ()
    } # CLEAR

sub SCALAR
{
    scalar %{$_[0]->{tblMeta}}
    } # SCALAR

# ====== Tie-Tables ============================================================

package DBD::File::TieTables;

use Carp qw(croak);
require Tie::Hash;
@DBD::File::TieTables::ISA = qw(Tie::Hash);

sub TIEHASH
{
    my ($class, $dbh) = @_;

    (my $tbl_class = $dbh->{ImplementorClass}) =~ s/::db$/::Table/;
    my $self = bless ({ dbh => $dbh, tblClass => $tbl_class, }, $class);
    return $self;
    } # new

sub STORE
{
    my ($self, $table, $tbl_meta) = @_;

    "HASH" eq ref $tbl_meta or
        croak "Invalid data for storing as table meta data (must be hash)";

    (undef, my $meta) = $self->{tblClass}->get_table_meta ($self->{dbh}, $table, 1);
    $meta or croak "Invalid table name '$table'";

    while (my ($meta_attr, $meta_val) = each %$tbl_meta) {
	$self->{tblClass}->set_table_meta_attr ($meta, $meta_attr, $meta_val);
	}

    return;
    } # STORE

sub FETCH
{
    my ($self, $table) = @_;

    (undef, my $meta) = $self->{tblClass}->get_table_meta ($self->{dbh}, $table, 1);
    $meta or croak "Invalid table name '$table'";

    my %h;
    tie %h, "DBD::File::TieMeta", $self->{tblClass}, $meta;

    return \%h;
    } # FETCH

sub FIRSTKEY
{
    my $a = scalar keys %{$_[0]->{dbh}->{f_meta}};
    each %{$_[0]->{dbh}->{f_meta}};
    } # FIRSTKEY

sub NEXTKEY
{
    each %{$_[0]->{dbh}->{f_meta}};
    } # NEXTKEY

sub EXISTS
{
    exists $_[0]->{dbh}->{f_meta}->{$_[1]} or
	exists $_[0]->{dbh}->{f_meta_map}->{$_[1]};
    } # EXISTS

sub DELETE
{
    my ($self, $table) = @_;

    (undef, my $meta) = $self->{tblClass}->get_table_meta ($self->{dbh}, $table, 1);
    $meta or croak "Invalid table name '$table'";

    delete $_[0]->{dbh}->{f_meta}->{$meta->{table_name}};
    } # DELETE

sub CLEAR
{
    %{$_[0]->{dbh}->{f_meta}} = ();
    %{$_[0]->{dbh}->{f_meta_map}} = ();
    } # CLEAR

sub SCALAR
{
    scalar %{$_[0]->{dbh}->{f_meta}}
    } # SCALAR

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
require File::Basename;
require File::Spec;
require Cwd;

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
    my ($self, $meta, $file, $file_is_table, $respect_case) = @_;

    $file eq "." || $file eq ".."	and return; # XXX would break a possible DBD::Dir

    my ($ext, $req) = ("", 0);
    if ($meta->{f_ext}) {
	($ext, my $opt) = split m/\//, $meta->{f_ext};
	if ($ext && $opt) {
	    $opt =~ m/r/i and $req = 1;
	    }
	}

    # (my $tbl = $file) =~ s/$ext$//i;
    my ($tbl, $dir, $user_spec_file);
    if ($file_is_table and defined $meta->{f_file}) {
	$tbl = $file;
	($file, $dir, undef) = File::Basename::fileparse ($meta->{f_file});
	$user_spec_file = 1;
	}
    else {
	($tbl, $dir, undef) = File::Basename::fileparse ($file, $ext);
	$user_spec_file = 0;
	}

    (Cwd::abs_path ($dir) eq $meta->{f_dir} or $dir eq "./") and
	$dir = "";

    !$respect_case and $meta->{sql_identifier_case} == 1 and # XXX SQL_IC_UPPER
        $tbl = uc $tbl;
    !$respect_case and $meta->{sql_identifier_case} == 2 and # XXX SQL_IC_LOWER
        $tbl = lc $tbl;
    my $searchdir = File::Spec->file_name_is_absolute ($dir)
	? $dir
	: File::Spec->catdir ($meta->{f_dir}, $dir);

    unless ($user_spec_file) {
	$file_is_table and $file = "$tbl$ext";

	# Fully Qualified File Name
	my $cmpsub;
	if ($respect_case) {
	    $cmpsub = sub {
		my ($fn, undef, $sfx) = File::Basename::fileparse ($_, qr/\.[^.]*/);
		$fn eq $tbl and
		    return (lc $sfx eq lc $ext or !$req && !$sfx);
		return 0;
		}
	    }
	else {
	    $cmpsub = sub {
		my ($fn, undef, $sfx) = File::Basename::fileparse ($_, qr/\.[^.]*/);
		lc $fn eq lc $tbl and
		    return (lc $sfx eq lc $ext or !$req && !$sfx);
		return 0;
		}
	    }

	opendir my $dh, $searchdir or croak "Can't open '$searchdir': $!";
	my @f = sort { length $b <=> length $a } grep { &$cmpsub ($_) } readdir $dh;
	@f > 0 && @f <= 2 and $file = $f[0];
	!$respect_case && $meta->{sql_identifier_case} == 4 and # XXX SQL_IC_MIXED
	    ($tbl = $file) =~ s/$ext$//i;
	closedir $dh or croak "Can't close '$searchdir': $!";

	#(my $tdir = $dir) =~ s{^\./}{};	# XXX We do not want all tables to start with ./
	#$tdir and $tbl = File::Spec->catfile ($tdir, $tbl);
	$dir and $tbl = File::Spec->catfile ($dir, $tbl);

	my $tmpfn = $file;
	if ($ext) {
	    if ($req) {
		# File extension required
		$tmpfn =~ s/$ext$//i			or  return;
		}
#	    else {
#		# File extension optional, skip if file with extension exists
#		grep m/$ext$/i, glob "$fqfn.*"	and return;
#		$tmpfn =~ s/$ext$//i;
#		}
	    }
	}

    my $fqfn = Cwd::abs_path (File::Spec->catfile ($searchdir, $file));
    my $fqbn = Cwd::abs_path (File::Spec->catfile ($searchdir, $tbl));

    $meta->{f_fqfn} = $fqfn;
    $meta->{f_fqbn} = $fqbn;
    !defined $meta->{f_lockfile} && $meta->{f_lockfile} and
	$meta->{f_fqln} = $meta->{f_fqbn} . $meta->{f_lockfile};

    $meta->{table_name} = $tbl;

    return $tbl;
    } # file2table

sub bootstrap_table_meta
{
    my ($self, $dbh, $meta, $table) = @_;

    exists  $meta->{f_dir}	or $meta->{f_dir}	= $dbh->{f_dir};
    defined $meta->{f_ext}	or $meta->{f_ext}	= $dbh->{f_ext};
    defined $meta->{f_encoding}	or $meta->{f_encoding}	= $dbh->{f_encoding};
    exists  $meta->{f_lock}	or $meta->{f_lock}	= $dbh->{f_lock};
    exists  $meta->{f_lockfile}	or $meta->{f_lockfile}	= $dbh->{f_lockfile};
    defined $meta->{f_schema}	or $meta->{f_schema}	= $dbh->{f_schema};
    defined $meta->{sql_identifier_case} or
        $meta->{sql_identifier_case} = $dbh->{sql_identifier_case};
    } # bootstrap_table_meta

sub init_table_meta
{
    my ($self, $dbh, $meta, $table) = @_;

    return;
    } # init_table_meta

sub get_table_meta ($$$$;$)
{
    my ($self, $dbh, $table, $file_is_table, $respect_case) = @_;
    unless (defined $respect_case) {
	$respect_case = 0;
	$table =~ s/^\"// and $respect_case = 1;    # handle quoted identifiers
	$table =~ s/\"$//;
	}

    defined $dbh->{f_meta_map}{$table} and $table = $dbh->{f_meta_map}{$table};

    my $meta = {};
    defined $dbh->{f_meta}{$table} and $meta = $dbh->{f_meta}{$table};

    unless ($meta->{initialized}) {
	$self->bootstrap_table_meta ($dbh, $meta, $table);

	unless (defined $meta->{f_fqfn}) {
	    $self->file2table ($meta, $table, $file_is_table, $respect_case) or return;
	    }

	if (defined $meta->{table_name} and $table ne $meta->{table_name}) {
	    $dbh->{f_meta_map}{$table} = $meta->{table_name};
	    $table = $meta->{table_name};
	    }

	# now we know a bit more - let's check if user can't use consequent spelling
	# XXX add know issue about reset sql_identifier_case here ...
	if (defined $dbh->{f_meta}{$table} && $dbh->{f_meta}{$table}{initialized}) {
	    $meta = $dbh->{f_meta}{$table};
	    }
	else {
	    $self->init_table_meta ($dbh, $meta, $table);
	    $meta->{initialized} = 1;
	    $dbh->{f_meta}{$table} = $meta;
	    }
	}

    return ($table, $meta);
    } # get_table_meta

sub get_table_meta_attr
{
    my ($class, $meta, $attrib) = @_;
    exists $meta->{$attrib} and
	return $meta->{$attrib};
    return;
    } # get_table_meta_attr

my %reset_on_modify = (
    f_file     => "f_fqfn",
    f_dir      => "f_fqfn",
    f_ext      => "f_fqfn",
    f_lockfile => "f_fqfn", # forces new file2table call
);

sub set_table_meta_attr
{
    my ($class, $meta, $attrib, $value) = @_;
    defined $reset_on_modify{$attrib} and
	delete $meta->{$reset_on_modify{$attrib}} and
	delete $meta->{initialized};
    $meta->{$attrib} = $value;
    } # set_table_meta_attr

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
		croak "Cannot open $fn for writing: $! (" . ($!+0) . ")";
	    }
	else {
	    unless ($fh = IO::File->new ($fn, ($flags->{lockMode} ? "r+" : "r"))) {
		croak "Cannot open $fn: $! (" . ($!+0) . ")";
		}
	    }

	if ($fh) {
	    $fh->seek (0, 0) or
		croak "Error while seeking back: $!";
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
		croak "Cannot open $fn for writing: $! (" . ($!+0) . ")";
	    }
	else {
	    unless ($fh = IO::File->new ($fn, ($flags->{lockMode} ? "r+" : "r"))) {
		croak "Cannot open $fn: $! (" . ($!+0) . ")";
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

    my ($tblnm, $meta) = $className->get_table_meta ($dbh, $attrs->{table}, 1) or
        croak "Cannot find appropriate file for table '$attrs->{table}'";
    $attrs->{table} = $tblnm;

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
    delete $data->{Database}{f_meta}{$self->{table}};
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

This module is a base class for writing other L<DBD|DBI::DBD>s.
It is not intended to function as a DBD itself (though it is possible).
If you want to access flat files, use L<DBD::AnyData|DBD::AnyData>, or
L<DBD::CSV|DBD::CSV> (both of which are subclasses of DBD::File).

=head1 DESCRIPTION

The DBD::File module is not a true L<DBI|DBI> driver, but an abstract
base class for deriving concrete DBI drivers from it. The implication
is, that these drivers work with plain files, for example CSV files or
INI files. The module is based on the L<SQL::Statement|SQL::Statement>
module, a simple SQL engine.

See L<DBI|DBI> for details on DBI, L<SQL::Statement|SQL::Statement> for
details on SQL::Statement and L<DBD::CSV|DBD::CSV>, L<DBD::DBM|DBD::DBM>
or L<DBD::AnyData|DBD::AnyData> for example drivers.

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

=head3 The following DBI attributes are handled by DBD::File:

=head4 AutoCommit

Always on

=head4 ChopBlanks

Works

=head4 NUM_OF_FIELDS

Valid after C<< $sth->execute >>

=head4 NUM_OF_PARAMS

Valid after C<< $sth->prepare >>

=head4 NAME

Valid after C<< $sth->execute >>; undef for Non-Select statements.

=head4 NULLABLE

Not really working, always returns an array ref of one's, as DBD::CSV
doesn't verify input data. Valid after C<< $sth->execute >>; undef for
Non-Select statements.

=head3 The following DBI attributes and methods are not supported:

=over 4

=item bind_param_inout

=item CursorName

=item LongReadLen

=item LongTruncOk

=back

=head3 DBD::File specific attributes

In addition to the DBI attributes, you can use the following dbh
attributes:

=head4 f_dir

This attribute is used for setting the directory where the files are
opened and it defaults to the current directory (F<.>). Usually you set
it on the dbh but it may be overridden per table (see L<f_meta>).

When the value for C<f_dir> is a relative path, it's converted into the
appropriate absolute path name (based on the current working directory)
when the dbh attribute is set.

See L<KNOWN BUGS AND LIMITATIONS>.

=head4 f_ext

This attribute is used for setting the file extension. The format is:

  extension{/flag}

where the /flag is optional and the extension is case-insensitive.
C<f_ext> allows you to specify an extension which:

=over

=item *

makes DBD::File prefer F<table.extension> over F<table>.

=item *

makes the table name the filename minus the extension.

=back

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

Usually you set it on the dbh but it may be overridden per table
(see L<f_meta>).

=head4 f_schema

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

Defining C<f_schema> to the empty string is equal to setting it to C<undef>
so the DSN can be C<"dbi:CSV:f_schema=;f_dir=.">.

=head4 f_lock

The C<f_lock> attribute is used to set the locking mode on the opened
table files. Note that not all platforms support locking.  By default,
tables are opened with a shared lock for reading, and with an
exclusive lock for writing. The supported modes are:

  0: No locking at all.

  1: Shared locks will be used.

  2: Exclusive locks will be used.

But see L<KNOWN BUGS|/"KNOWN BUGS AND LIMITATIONS"> below.

=head4 f_lockfile

If you wish to use a lockfile extension other than C<.lck>, simply specify
the C<f_lockfile> attribute:

  $dbh = DBI->connect ("dbi:DBM:f_lockfile=.foo");
  $dbh->{f_lockfile} = ".foo";
  $dbh->{f_meta}{qux}{f_lockfile} = ".foo";

If you wish to disable locking, set the C<f_lockfile> to C<0>.

  $dbh = DBI->connect ("dbi:DBM:f_lockfile=0");
  $dbh->{f_lockfile} = 0;
  $dbh->{f_meta}{qux}{f_lockfile} = 0;

=head4 f_encoding

With this attribute, you can set the encoding in which the file is opened.
This is implemented using C<< binmode $fh, ":encoding(<f_encoding>)" >>.

=head4 f_meta

Private data area which contains information about the tables this
module handles. Meta data of a table might not be available until the
table has been accessed for the first time e.g., by issuing a select
on it however it's possible to pre-initialize attributes for each table
you use.

DBD::File recognizes the (public) attributes C<f_ext>, C<f_dir>,
C<f_file>, C<f_encoding>, C<f_lock>, C<f_lockfile>, C<f_schema>,
C<col_names>, C<table_name> and C<sql_identifier_case>. Be very careful
when modifying attributes you do not know, the consequence might be a
destroyed or corrupted table.

C<f_file> is an attribute applicable to table meta data only and you
will not find a corresponding attribute in the dbh. Whilst it may be
reasonable to have several tables with the same column names, it's not
for the same file name. If you need access to the same file using
different table names, use C<SQL::Statement> as the SQL engine and the
C<AS> keyword:

    SELECT * FROM tbl AS t1, tbl AS t2 WHERE t1.id = t2.id

C<f_file> can be an absolute path name or a relative path name. If
it's relative, it's interpreted as being relative to the C<f_dir>
attribute of the table meta data. When C<f_file> is set DBD::File
will use C<f_file> as specified and will not attempt to work out an
alternative for C<f_file> using the C<table name> and C<f_ext> attribute.

While C<f_meta> is a private and readonly attribute (which means, you
cannot modify it's values), derived drivers might provide restricted
write access through another attribute. Well known accessors are
C<csv_tables> for L<DBD::CSV>, C<ad_tables> for L<DBD::AnyData> and
C<dbm_tables> for L<DBD::DBM>.

=head3 Internally private attributes to deal with SQL backends:

Do not modify any of these private attributes unless you understand
the implications of doing so. The behavior of DBD::File and derived
DBD's might be unpredictable when one or more of those attributes are
modified.

=head4 sql_nano_version

Contains the version of loaded DBI::SQL::Nano

=head4 sql_statement_version

Contains the version of loaded SQL::Statement

=head4 sql_handler

Contains either the text 'SQL::Statement' or 'DBI::SQL::Nano'.

=head4 sql_ram_tables

Contains optionally temporary tables.

=head4 sql_flags

Contains optional flags to instantiate the SQL::Parser parsing engine
when SQL::Statement is used as SQL engine. See L<SQL::Parser> for valid
flags.

=head2 Driver private methods

=head3 Default DBI methods

=head4 data_sources

The C<data_sources> method returns a list of subdirectories of the current
directory in the form "dbi:CSV:f_dir=$dirname".

If you want to read the subdirectories of another directory, use

    my ($drh)  = DBI->install_driver ("CSV");
    my (@list) = $drh->data_sources (f_dir => "/usr/local/csv_data" );

=head4 list_tables

This method returns a list of file names inside $dbh->{f_dir}.
Example:

    my ($dbh)  = DBI->connect ("dbi:CSV:f_dir=/usr/local/csv_data");
    my (@list) = $dbh->func ("list_tables");

Note that the list includes all files contained in the directory, even
those that have non-valid table names, from the view of SQL.

=head3 Additional methods

The following methods are only available via their documented name when
DBD::File is used directly. Because this is only reasonable for testing
purposes, the real names must be used instead. Those names can be computed
by replacing the C<f_> in the method name with the driver prefix.

=head4 f_versions

Signature:

    sub f_versions (;$)
    {
	my ($table_name) = @_;
	$table_name ||= ".";
	...
    }

Returns the versions of the driver, including the DBI version, the Perl
version, DBI::PurePerl version (if DBI::PurePerl is active) and the version
of the SQL engine in use.

    my $dbh = DBI->connect ("dbi:File:");
    my $f_versions = $dbh->f_versions ();
    print "$f_versions\n";
    __END__
    # DBD::File        0.39 using SQL::Statement 1.28
    # DBI              1.612
    # OS               netbsd (5.99.24)
    # Perl             5.010001 (x86_64-netbsd-thread-multi)

Called in list context, f_versions will return an array containing each
line as single entry.

Some drivers might use the optional (table name) argument and modify some
version information related to the table (e.g. DBD::DBM provides storage
backend information for the requested table, when it has a table name).

=head4 f_get_meta

Signature:

    sub f_get_meta ($$)
    {
	my ($table_name, $attrib) = @_;
	...
    }

Returns the value of a meta attribute set for a specific table, if any.
See L<f_meta> for the possible attributes.

A table name of C<'.'> (single dot) is interpreted as the default table.
This will retrieve the appropriate attribute globally from the dbh.
This has the same restrictions as C<< $dbh->{$attrib} >>.

=head4 f_set_meta

Signature:

    sub f_set_meta ($$$)
    {
	my ($table_name, $attrib, $value) = @_;
	...
    }

Sets the value of a meta attribute set for a specific table.
See L<f_meta> for the possible attributes.

A table name of C<'.'> (single dot) is interpreted as the default table.
This causes in setting the appropriate attribute globally for the dbh.
This has the same restrictions as C<< $dbh->{$attrib} = $value >>.

=head4 f_clear_meta

Signature:

    sub f_clear_meta ($)
    {
	my ($table_name) = @_;
	...
    }

Clears the table specific meta information in the private storage of the
dbh.

=head1 SQL ENGINES

DBD::File currently supports two SQL engines: L<SQL::Statement|SQL::Statement>
and L<DBI::SQL::Nano::Statement_|DBI::SQL::Nano>. DBI::SQL::Nano supports a
I<very> limited subset of SQL statements, but it might be faster for some
very simple tasks. SQL::Statement in contrast supports a much larger subset
of ANSI SQL.

To use SQL::Statement, you need at least version 1.28 of
SQL::Statement and the environment variable C<DBI_SQL_NANO> must not
be set to a true value.

=head1 KNOWN BUGS AND LIMITATIONS

=over 4

=item *

This module uses flock () internally but flock is not available on all
platforms. On MacOS and Windows 95 there is no locking at all (perhaps
not so important on MacOS and Windows 95, as there is only a single
user).

=item *

The module stores details about the handled tables in a private area
of the driver handle (C<$drh>). This data area isn't shared between
different driver instances, so several C<< DBI->connect () >> calls will
cause different table instances and private data areas.

This data area is filled for the first time when a table is accessed,
either via an SQL statement or via C<table_info> and is not
destroyed until the table is dropped or the driver handle is released.
Manual destruction is possible via L<f_clear_meta>.

The following attributes are preserved in the data area and will
evaluated instead of driver globals:

=over 8

=item f_ext

=item f_dir

=item f_lock

=item f_lockfile

=item f_encoding

=item f_schema

=item col_names

=item sql_identifier_case

=back

The following attributes are preserved in the data area only and
cannot be set globally.

=over 8

=item f_file

=back

The following attributes are preserved in the data area only and are
computed when initializing the data area:

=over 8

=item f_fqfn

=item f_fqbn

=item f_fqln

=item table_name

=back

For DBD::CSV tables this means, once opened 'foo.csv' as table named 'foo',
another table named 'foo' accessing the file 'foo.txt' cannot be opened.
Accessing 'foo' will always access the file 'foo.csv' in memorized
C<f_dir>, locking C<f_lockfile> via memorized C<f_lock>.

You can use L<f_clear_meta> or the C<f_file> attribute for a specific table
to work around this.

=item *

When used with SQL::Statement and temporary tables e.g.,

  CREATE TEMP TABLE ...

the table data processing bypasses DBD::File::Table. No file system
calls will be made and there are no clashes with existing (file based)
tables with the same name. Temporary tables are chosen over file
tables, but they will not covered by C<table_info>.

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

L<DBI|DBI>, L<DBD::DBM|DBD::DBM>, L<DBD::CSV|DBD::CSV>, L<Text::CSV|Text::CSV>,
L<Text::CSV_XS|Text::CSV_XS>, L<SQL::Statement|SQL::Statement>, and
L<DBI::SQL::Nano|DBI::SQL::Nano>

=cut
