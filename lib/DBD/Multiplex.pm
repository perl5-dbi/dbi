#########1#########2#########3#########4#########5#########6#########7#########8
# vim: ts=8:sw=4

# $Id$
#
# Copyright (c) 1999,2002,2003 Tim Bunce & Thomas Kishel
#
# You may distribute under the terms of either the GNU General Public
# License or the Artistic License, as specified in the Perl README file.

# The plan
#	mx_errors = ignore (unless all fail) | first | last
#	mx_results = first | last | union
#	mx_pick_handles = sub
#	mx_pick_results = sub
#	mx_connect_* = as above but only applies to connect
#	mx_reconnect = true | false - ping & auto reconnect

# some file-scoped lexicals:

my %parent_only_attr = (
    # mx needs to manage errors from children
    RaiseError => 1, PrintError => 1, HandleError => 1,
    # Kids would give wrong counts
    Kids => 1, ActiveKids => 1, CachedKids => 0,
    Profile => 1,	# profile at the mx level
    Statement => 1,	# else first_success + mx_shuffle of prepare() give wrong results
);

my %do_not_mx_method = (
    # error handling is all done at mx level
    err => 1, errstr => 1, state => 1, set_err => 1,
    trace_msg => 1,	# so we only get one
    _not_impl => 1,	# pointless to mx
    do => 1,		# so do() uses prepare()
    can => 1,		# XXX
    DESTROY => 1,	# else becomes explicit for children
);
my %do_not_mx_method_db = (%do_not_mx_method, clone=>1);
my %do_not_mx_method_st = (%do_not_mx_method, _set_fbav=>1);
my %call_super_method_first = map { $_=> 1 } qw(trace);

# Override both the default exit_mode,
# and the exit_mode attribute stored in the parent handle,
# when multiplexing the following:
my %exit_mode_override = (
    STORE	=> 'first_error',
    FETCH	=> 'first_error',
    finish	=> 'last_result',
    disconnect	=> 'last_result',
);


{ #=================================================================== DBD ===

package DBD::Multiplex;

use DBI ();

use strict;
use vars qw($VERSION $drh);

$VERSION = sprintf("2.%06d", q$Revision$ =~ /(\d+)/o);

$drh = undef;	# Holds driver handle once it has been initialized.


#########################################
# The driver handle constructor.
#########################################

sub driver {
    return $drh if ($drh);
    my ($class, $attr) = @_;

    $class .= "::dr";

    # $drh is not scoped with 'my', 
    # since we use it above to prevent multiple drivers.

    ($drh) = DBI::_new_drh ($class, {
	    'Name' => 'Multiplex',
	    'Version' => $VERSION,
	    'Attribution' => 'DBD Multiplex by Tim Bunce & Thomas Kishel',
    });
    $drh->STORE(CompatMode => 1); # disable attrib 'quick FETCH' by DBI (>=1.36)

    return $drh;
}

sub CLONE {
    undef $drh;
}

sub dump_handle {
    my ($h, $msg, $level) = @_;
    $msg   ||= "DBD::Multiplex";
    $level ||= 0;
    $h->DBD::_::common::dump_handle($msg, $level);
    $_->DBD::_::common::dump_handle("$msg ".($_->{mx_id} || $_->{Name} || $_), $level)
	foreach (@{ $h->{mx_handle_list} });
}


sub mx_statement_escape {
    my ($dbh, $sth, $spec) = @_;
    # $sth probably isn't an actual sth, just a hash ref of attr's for prepare()
    $spec =~ m/^([\.\w]+?)=(.*)?/;
    my ($attr, $value) = ($1, $2);
    # unless attrib name starts with 'dbh.' assign it to sth attr
    # because curently dbh changes are persistent - needs more thought
    my $h = ($attr =~ s/^(dbh|sth)\.// && $1 eq 'dbh') ? $dbh : $sth;
    if (defined $value) { # assignment
	$dbh->trace_msg(" mx .. statement_escape($spec): $h\->{$attr}=$value\n");
	$h->{$attr} = $value;
	return "";
    }
    $dbh->trace_msg(" mx .. statement_escape($spec): $h\->{$attr}\n");
    $h->{$attr} = $value;
    return $h->{$attr};
}


########################################
# Function for calling a method for each child handle of a parent handle.
# The parent handle is one of 'our' database or statement handles.
# Each of the child handles is a 'native' database or statement handle.
# Called inside AUTOLOAD in some cases
########################################

sub mx_method_all {
    # Remember that shift modifies the parameter list.
    my ($method, $parent_handle) = (shift, shift);

    $parent_handle->trace_msg(" mx => $method($parent_handle, ...)\n");

    my $exit_mode = $exit_mode_override{$method} || $parent_handle->{mx_exit_mode};

    $exit_mode = 'all' if $parent_handle->{mx_as_select} && $method eq 'execute'; # XXX

    my ($results, $errors, $handles, $error_count) = DBD::Multiplex::mx_do_calls(
	    $parent_handle, $method, wantarray, { exit_mode => $exit_mode }, @_);

    if ($method eq 'execute' && $parent_handle->{mx_as_select}) {
	if ($error_count < @$handles			# at least one worked
	    && !$parent_handle->FETCH('NUM_OF_FIELDS')	# is not a SELECT
	) {
	    # we only set mx_as_select_results if at least one handle didn't have an error
	    # apart from being generally sane, execute() logic requires this
	    # else a failed select may be turned into "mx_as_select" style results
	    # which would be unpleasant and error prone in applications.
	    $parent_handle->trace_msg(" mx -- setting mx_as_select_results\n");
	    $parent_handle->{mx_as_select_results} = [ $results, $errors, $handles ];
	}
	else {
	    delete $parent_handle->{mx_as_select_results};
	}
    }

    # this is where result-selection/comparision functionality can go
    my $return_result = $results->[0];

    return $return_result->[0] unless wantarray;
    return @$return_result;
}


########################################
# 'Bottom-level' support function to multiplex the calls.
# See the documentation for information about $exit_mode.
# Currently the 'last_result' exit_mode is automagic.	
########################################

sub mx_do_calls {
    # Remember that shift modifies the parameter list.
    my ($parent_handle, $method, $wantarray, $mx_options, @args) = @_;

    my $exit_mode = $mx_options->{exit_mode} || 'first_error';

    my @child_handles = $parent_handle->{mx_pick_handles}->(@_);

    my $trace_level = $parent_handle->DBD::_::db::FETCH('TraceLevel');
    if ($trace_level) {
	my $live_handles = grep { $_ } @child_handles;
	my @opts = join ", ", map { my $v; (/^mx_/ and $v=$parent_handle->{$_} and !ref $v) ? ("$_=>$v") : () } keys %$parent_handle;
	$parent_handle->trace_msg(" mx => calling $method for $live_handles children, exit_mode=$exit_mode (@opts)\n");
    }

    # @errors is a sparse array paralleling $results[0..n] and empty if no errors
    my ($args, @results, @errors);
    my @error_list;

    foreach my $child_handle (@child_handles) {
	next unless $child_handle; # may (only) happen during global destruction

	if ($method eq 'prepare') {
	    my @new_args = @args;
	    $args = \@new_args;
	    my $id = $child_handle->{dbd_mx_info}->{mx_id};
	    $args->[0] =~ s/{dbi (\w+)}/($1 eq 'id') ? $id : $child_handle->{$1}/eg;
	    next if $args->[0] =~ s/{mx only (.*?)}// && !grep { $_ eq $id } split /,/,$1
	}
	else {
	    $args = \@args;
	}

	if ($trace_level) {
	    $parent_handle->trace_msg(" mx ++ calling $child_handle->$method(".DBI::neat_list($args).")\n");
	}

# XXX need to always force RaiseError on the child handles so we can let the DBI
# work out when an error has happened rather than have to duplicate the logic here
# (which is difficult and slow given FETCH and ErrorCount behaviour)

	local $@;
	# Here, the actual method being multiplexed is being called.
	push @results, ($wantarray) 
		? [ eval {        $child_handle->$method(@$args) } ]
		: [ eval { scalar $child_handle->$method(@$args) } ];

	if ($@) {
	    my $child_err = $child_handle->err;
	    my $child_errstr = $child_handle->errstr;
	    my $error_info = [ $child_err, $child_errstr, $child_handle ];
	    $errors[@results - 1] = $error_info;
	    push @error_list, $error_info;
	    my $mx_info = $child_handle->{dbd_mx_info};
	    $parent_handle->set_err($child_err, "$child_errstr [from mx_id=$mx_info->{mx_id}: $mx_info->{dsn}]")
		unless $exit_mode eq 'ignore';
	    if (my $error_proc = $parent_handle->{mx_error_proc}) {
		$error_proc->($mx_info->{dsn}, $mx_info->{mx_id}, $child_err, $child_errstr, $child_handle);
	    }
	    last if ($exit_mode eq 'first_error');
	}
	else {
	    last if ($exit_mode eq 'first_success');
	}
    }
    if ($exit_mode eq 'ignore' && @error_list == @results) {
	# they all failed, we don't ignore the error in this case
	my $last_error = $error_list[-1];
	$parent_handle->set_err($last_error->[0], $last_error->[1]);
    }

    $parent_handle->trace_msg(sprintf " mx <= %s (exit_mode=%s, %d results, %d errors)\n\n",
	$method, $exit_mode, scalar @results, scalar @error_list);
    
    return (\@results, \@errors, \@child_handles, scalar @error_list);
}


########################################
# Identify if the statement modifies data in the datasource.
# EP Added CREATE and DROP.
# TK Consider when these words occur in the data of a statement.
########################################

sub mx_strip_comments {
    my $statement = shift || '';
    # strip away leading space and comments
    1 while $statement =~ s!(?:/\*.*?\*/|--.*?\n|\s+)!!s;
    return $statement;
}

sub mx_is_modify_statement {
    my $statement = mx_strip_comments(shift) or return;

    # XXX this is fairly poor really, but it'll do for now
    return 1 if $statement =~ /^(INSERT|UPDATE|DELETE|CREATE|DROP|ALTER)\b/i;
    return 0;
}


########################################
# Example error logging mechanism.
########################################

sub mx_error_subroutine {
    my ($dsn, $mx_id, $error, $error_string, $h) = @_;
    print STDERR "DSN: $dsn\;mx_id\=$mx_id\n";
    print STDERR "ERROR: $error: $error_string\n";
    return 1;
}


} #=============================================================== END DBD ===

{ #================================================================ DRIVER ===

package DBD::Multiplex::dr;
    $imp_data_size = $imp_data_size = 0;
    use strict;

########################################
# The database handle constructor.
# This function cannot be called using mx_method_all.
########################################

sub _load_logic {	# map logic role name to code ref
    my ($h, $role, $value) = @_;
    $value ||= 'Default';
    return $value if ref $value eq 'CODE';
    my $module = "DBD::Multiplex::Logic::$value";
    eval "require $module";
    return $h->set_err($@, "$module: $@") if $@;
    my $subname = "${module}::$role";
    return $h->set_err($@, "$module: $role subroutine not defined")
	unless defined &$subname;
    return \&$subname;
}

sub connect {
    my ($drh, $dsn, $user, $auth, $attr) = @_;
    
    # strip off any leading 'dsn=' that the DBI_AUTOPROXY mechanism adds
    $dsn =~ s/^;?(dsn=)?//;

    my @dsn_list = split (/\|/, $dsn); # DSNs from the $dsn parameter
    push @dsn_list, @{ delete $attr->{mx_dsns} }  if $attr->{mx_dsns};
    push @dsn_list, @dsn_list                     if $attr->{mx_double};
    push @dsn_list, @dsn_list, @dsn_list          if $attr->{mx_triple};
    return $drh->set_err($DBI::stderr, "No dsn given") unless @dsn_list;
    my @orig_dsn_list = @dsn_list; # @dsn_list gets edited below

    # exit_mode decides when to exit the foreach loop.
    # error_proc is a code reference to execute in case of an execute error.
    my $exit_mode  = $attr->{'mx_exit_mode'} || 'first_error';
    my $error_proc = delete $attr->{'mx_error_proc'} || '';
    $error_proc = \&DBD::Multiplex::mx_error_subroutine if $error_proc eq 'DEFAULT';

    my $mx_pick_handles = _load_logic($drh, "mx_pick_handles", delete $attr->{mx_pick_handles})
	or return; # set_err already called

    # Initiate mx_connect_limit
    my @mx_connect_count = (0,0,0);   # [read-write, read-only, write-only]
    my @mx_connect_limit = (0,0,0);
    if (defined $attr->{mx_connect_limit}){
	$mx_connect_limit[0] = int($2) if ( $attr->{mx_connect_limit} =~ /(read-write=)(\d+);?/ );
	$mx_connect_limit[1] = int($2) if ( $attr->{mx_connect_limit} =~ /(read-only=)(\d+);?/ );
	$mx_connect_limit[2] = int($2) if ( $attr->{mx_connect_limit} =~ /(write-only=)(\d+);?/ );
    }

    if (($attr->{mx_shuffle} || $attr->{mx_shuffle_connect}) && @dsn_list > 1) {
        my $deck = \@dsn_list;  # take ref for in-place shuffle
        my $i = @$deck;
        while (--$i) {
            my $j = int rand ($i+1);
            @$deck[$i,$j] = @$deck[$j,$i];
        }
    }

    my %child_connect_attr = %$attr;	# copy supplied attributes

    # delete error handling attribute that we want handled only at top level
    delete $child_connect_attr{$_} for (qw(RaiseError HandleError));
    $child_connect_attr{RaiseError} = 1; # explicitly silence default
    $child_connect_attr{PrintError} = 0; # explicitly silence default

    # delete any multiplex specific attributes from child connect
    m/^mx_/ && delete $child_connect_attr{$_} for keys %child_connect_attr;

    my ($err, $errstr);
    my @mx_dbh_list;

    for my $dsn (@dsn_list) {	# Connect to each dsn in the dsn_list.

	# Retrieve the datasource mx_id for use by the error_proc.
	# Remove the datasource mx_id from the driver name.
	# There is no standard for the text following the driver name.
	# Each driver is free to use whatever syntax it wants.
	$dsn =~ s/\bmx_id=(\w+);?//;
	my $mx_id = (defined $1) ? $1 : $dsn;

	# Retrieve the datasource mx_type
	my $type_match = ($dsn =~ s/\bmx_type=(\w+);?//) ? $1 : '';
	my $mx_type = {
			R => ( (!$type_match || $type_match =~ m/read/i) ? 1 : 0 ),
			W => ( (!$type_match || $type_match =~ m/write/i) ? 1 : 0 ),
		};
	$mx_type->{W} = 0 if ( defined($attr->{mx_master_id}) && $attr->{mx_master_id} ne $mx_id );

	# Check if we've reached mx_connect_limit
	if ( grep {!/^0$/} @mx_connect_limit ){
		if ( $mx_type->{R} && $mx_type->{W} ){
			next if $mx_connect_count[0] >= $mx_connect_limit[0];
			$mx_connect_count[0]++;
		} elsif ( $mx_type->{R} ){
			next if $mx_connect_count[1] >= $mx_connect_limit[1];
			$mx_connect_count[1]++;
		} elsif ( $mx_type->{W} ){
			next if $mx_connect_count[2] >= $mx_connect_limit[2];
			$mx_connect_count[2]++;
		}
	}

	my $dbh = DBI->connect($dsn, $user, $auth, \%child_connect_attr);
	if ($dbh) {
	    push @mx_dbh_list, $dbh;
	    $dbh->{dbd_mx_info} = { dsn => $dsn, mx_id => $mx_id, mx_type => $mx_type };
	}
	else {
	    ($err, $errstr) = ($DBI::err, $DBI::errstr);

	    if (    # application wants to ignore connect errors
		    ($attr->{mx_connect_mode}||'') eq 'ignore_errors'
		    # and this is not the mx_master_id
		    and !(defined($attr->{mx_master_id}) && $attr->{mx_master_id} eq $mx_id)
	    ) {
		# XXX would be good to have a simple way to get PrintError effect here
		$error_proc->($dsn, $mx_id, $err, $errstr, undef)
		    if $error_proc;
		next; # failure of all connects is detected after the loop
	    }

	    # The forced DESTROY before calling set_err using pre-cached values
	    # is due to a wierd DBI interaction re errors and 'last handle'
	    undef @mx_dbh_list;	# force DESTROY now
	    $drh->set_err($err, "$errstr [from mx_id=$mx_id: $dsn]");
	    return;
	}
    }
    unless (@mx_dbh_list) {	# couldn't connect to anything!
	return $drh->set_err($err, $errstr);
    }
    
    my $this = DBI::_new_dbh ($drh, {
	'Name' => $mx_dbh_list[0]->{Name}, # adopt Name of first child
	'User' => $user,
	mx_handle_list	=> \@mx_dbh_list,
	mx_dsn_list	=> join("|", @orig_dsn_list),
	mx_master_id	=> delete $attr->{mx_master_id},
	mx_exit_mode	=> delete $attr->{mx_exit_mode},
	mx_error_proc	=> $error_proc,
	mx_pick_handles	=> $mx_pick_handles,
    });
    $this->SUPER::STORE('Active', 1);

    return $this;
}

sub DESTROY { } # needed re AUTOLOAD

sub disconnect_all { } # needed for DBI < ~1.35


} #============================================================ END DRIVER ===

{ #============================================================== DATABASE ===

package DBD::Multiplex::db; 
	$imp_data_size = $imp_data_size = 0;
	use strict;

########################################
# The statement handle constructor. 
# This function calls mx_do_calls and therefore cannot be called using mx_method_all.
# TK Note:
# Consider the interaction between prepare, execute, and mx_error_proc.
########################################

sub prepare {
    my ($dbh, $statement, $attr_param) = @_;
    my $attr = { ($attr_param) ? %$attr_param : () }; # take copy to edit

    # edit $attr for this prepare()
    $statement =~ s/{mx (.*?)}/DBD::Multiplex::mx_statement_escape($dbh, $attr, $1)/eg
	and $dbh->trace_msg("$statement [@{[ %$attr ]}]\n");

    # $sth_outer is a reference to the outer hash (used by the application).
    # $sth_inner is a reference to the inner hash (used by the driver).
    # create sth before executing prepare to get correct semantics (incl Statement)
    my ($sth_outer, $sth_inner) = DBI::_new_sth ($dbh, {
	Statement => $statement,
	map { 
	    $_ => (exists $attr->{$_}) ? $attr->{$_} : $dbh->{$_}
	} qw(mx_master_id mx_exit_mode mx_error_proc mx_union mx_as_select mx_pick_handles),
    });

    # The user can set the exit_mode of a new or existing database handle.
    # Otherwise, parse the SQL statement to determine the exit_mode.
    my $exit_mode = $sth_inner->{mx_exit_mode} ||
	DBD::Multiplex::db::mx_default_statement_mode($dbh, $statement);

    my ($results, $errors, $handles)
	= DBD::Multiplex::mx_do_calls($dbh, 'prepare', wantarray,
			    { exit_mode => $exit_mode, }, $statement, $attr);

    return if @$errors;

    my @mx_handle_list = map { $_->[0] } @$results;
    foreach my $child_sth (@mx_handle_list) {
	# copy dbd_mx_info down from dbh to corresponding sth
	$child_sth->{dbd_mx_info} = $child_sth->{Database}->{dbd_mx_info};
    }
    $sth_inner->{mx_handle_list} = \@mx_handle_list;

    return $sth_outer;
}


sub disconnect {
    $_[0]->SUPER::STORE('Active',0);
    return DBD::Multiplex::mx_method_all('disconnect', @_);
}


########################################
# Some attributes are stored in the parent handle.
# some in each of the children handles.
# This function uses and therefore cannot be called using mx_method_all.
########################################

sub STORE {
    my ($dbh, $attr, $val) = @_;

    if ($attr =~ /^mx_(.+)/) {
	return $dbh->SUPER::STORE($attr, $val) if $1 eq uc($1);
	return $dbh->{$attr} = $val;
    }
    $dbh->SUPER::STORE($attr, $val) # set attribute for parent
	unless $attr eq 'AutoCommit';

    # some attribute should only be set in the parent
    return if $parent_only_attr{$attr};

    # Store the attribute in each of the children handles.
    return DBD::Multiplex::mx_method_all('STORE', @_);
}


########################################
# Some attributes are stored in the parent handle.
# some in each of the children handles.
# This function uses and therefore cannot be called using mx_method_all.
########################################

sub FETCH {
    my ($h, $attr) = @_;

    if ($attr =~ /^mx_(.+)/) {
	return $h->SUPER::FETCH($attr) if $1 eq uc($1);
	return $h->{$attr};
    }
    return $h->SUPER::FETCH($attr) if $parent_only_attr{$attr};

    # return first_success from a child
    my ($results, $errors) = DBD::Multiplex::mx_do_calls($h, 'FETCH', 0,
		{ exit_mode=>'first_success' }, $attr);
    return $results->[0][0];
}


sub DESTROY { } # needed re AUTOLOAD

########################################
# The default behaviour is to not multiplex simple select statements.
# The resulting statement handle then contains only one child handle,
# automatically resulting in subsequent methods executed against the 
# statement handle to use 'first_success' mode.
########################################

sub mx_default_statement_mode {
    my ($h, $statement) = @_;
    $statement = DBD::Multiplex::mx_strip_comments($statement);
    
    # XXX poor parsing and show is mysql specific
    if (($statement =~ /^(SELECT|SHOW)\b/i)
	and !DBD::Multiplex::mx_is_modify_statement($statement)
    ) {
	return 'first_success' unless $h->{mx_union};
    }
    return;
}


########################################
# Replace this with dynamic information from updated DBI.
# Needs expanding manually in the short term.
# Look at %DBI_IF in DBI.pm for details.
########################################

sub mx_method_closure_db {
    my ($method, $super) = @_;
    return sub {
	my $h = shift;
	if ($super) {
	    my $meth = "SUPER::$method";
	    $h->$meth(@_);
	}
	return DBD::Multiplex::mx_method_all($method, $h, @_);
    };
}

no strict 'refs';

*dump_handle = \&DBD::Multiplex::dump_handle;
for (sort keys %{ $DBI::DBI_methods{db} }) {
    next if defined &$_; # we have defined our own
    next if $do_not_mx_method_db{$_};
    DBI->trace_msg("     installing \$dbh->$_ method for DBD::Multiplex\n");
    *$_ = mx_method_closure_db($_, $call_super_method_first{$_})
}


######################################## 
# AUTOLOAD to catch methods not explictly handled elsewhere,
# including driver-specific methods, and multiplex via func
# XXX using func isn't quite right, integrate with install_method/can?
########################################

sub AUTOLOAD {
    my $method = $DBD::Multiplex::db::AUTOLOAD;
    $method =~ s/^DBD::Multiplex::db:://;
    $_[0]->trace_msg("    mx AUTOLOAD \$dbh->$method via func()\n");
    # do last to propagate list/scalar context
    return DBD::Multiplex::mx_method_all('func', @_, $method);
}


} #========================================================== END DATABASE ===

{ #============================================================= STATEMENT ===

package DBD::Multiplex::st; 
$imp_data_size = $imp_data_size = 0;
use strict;

########################################
# Some attributes are stored in the parent handle.
# some in each of the children handles.
# This function uses and therefore cannot be called using mx_method_all.
########################################

sub STORE {
    my ($h, $attr, $val) = @_;

    if ($attr =~ /^mx_(.+)/) {
	return $h->SUPER::STORE($attr, $val) if $1 eq uc($1);
	return $h->{$attr} = $val;
    }
    $h->SUPER::STORE($attr, $val); # set attribute for parent

    # some attribute should only be set in the parent
    return if $parent_only_attr{$attr};

    # Store the attribute in each of the children handles.
    return DBD::Multiplex::mx_method_all('STORE', @_);
}


########################################
# Some attributes are stored in the parent handle.
# some in each of the children handles.
# This function uses and therefore cannot be called using mx_method_all.
########################################

sub FETCH {
    my ($h, $attr) = @_;

    if ($attr =~ /^mx_(.+)/) {
	return $h->SUPER::FETCH($attr) if $1 eq uc($1);
	return $h->{$attr};
    }
    return $h->SUPER::FETCH($attr) if $parent_only_attr{$attr};

    # return first_success from a child
    my ($results, $errors) = DBD::Multiplex::mx_do_calls($h, 'FETCH', 0,
		{ exit_mode=>'first_success' }, $attr);
    return $results->[0][0];
}


sub DESTROY { } # needed re AUTOLOAD

sub execute {
    my $sth = shift;

    my $rows = DBD::Multiplex::mx_method_all('execute', $sth, @_);
    return $rows if !defined $rows;

    if ($sth->{mx_as_select_results} && !$sth->FETCH('NUM_OF_FIELDS')) {
	# Is a non-select that application wants to treat as a select.
	$sth->trace_msg(" mx .. execute: setup as a fake select\n");
	$sth->{NAME} = [ qw(rows mx_id err errstr info) ];
	$sth->{TYPE} = [ DBI::SQL_INTEGER, (DBI::SQL_VARCHAR) x 4 ];
	$sth->SUPER::STORE(NUM_OF_FIELDS => 5);
	$sth->SUPER::STORE(Active => 1);
	$sth->{mx_union} = 1;     	# disable normal fetchrow_arrayref
	$sth->{mx_exit_mode} = 'all';	# XXX
	$sth->set_err(0, undef);	# clear error, if any
	# mx_method_all() has set {mx_as_select_results} for us
    }
    elsif ($sth->{mx_union}) {
	# DBI internals need NUM_OF_FIELDS set on parent sth for _set_fbav()
	$sth->SUPER::STORE(NUM_OF_FIELDS => $sth->FETCH('NUM_OF_FIELDS'))
	    unless $sth->SUPER::FETCH('NUM_OF_FIELDS'); # already set
    }
    return $rows;
}

sub fetchrow_arrayref {
    my $sth = shift;

    # unless $sth->{mx_union} then just mx this call as usual
    return DBD::Multiplex::mx_method_all('fetchrow_arrayref', $sth)
	unless my $mx_union = $sth->{mx_union};

    # for mx_union, do fetchall_arrayref (note the *all*) on each child.
    # for mx_as_select, move mx_as_select_results over to mx_row_cache.
    # cache the results, and feed them back from the cache
    my $mx_row_cache = $sth->{mx_row_cache};
    unless ($mx_row_cache) {
	if ($sth->{mx_as_select_results}) {
	    my ($results, $errors, $handles) = @{ $sth->{mx_as_select_results} };
	    for my $result (@$results) {
		my $error = shift @$errors;
		my $h = shift @$handles;
		push @$mx_row_cache, [
			$h->rows,
			$h->{dbd_mx_info}{mx_id},
			$error->[0], $error->[1],
			$h->{mysql_info},
		];
	    }
	    $sth->{mx_as_select_results} = undef;
	}
	else {
	    my ($results, $errors) = DBD::Multiplex::mx_do_calls($sth, 'fetchall_arrayref', 0,
			{ exit_mode=>'first_error' });
	    push @$mx_row_cache, map { $_->[0] ? @{$_->[0]} : () } @$results;
	}
	$sth->{mx_row_cache} = $mx_row_cache;
    }
    return $sth->_set_fbav(shift @$mx_row_cache) if @$mx_row_cache;
    $sth->SUPER::STORE(Active => 0);
    $sth->{mx_row_cache} = undef;
    return;
}


########################################
# Replace this with dynamic info from updated DBI.
# Needs expanding manually in the short term.
# Look at %DBI_IF in DBI.pm for details.
########################################

sub mx_method_closure_st {
    my ($method, $super) = @_;
    return sub {
	my $h = shift;
	if ($super) {
	    my $meth = "SUPER::$method";
	    $h->$meth(@_);
	}
	return DBD::Multiplex::mx_method_all($method, $h, @_);
    };
}

no strict 'refs';

*fetch = \&fetchrow_arrayref; # standard alias
*dump_handle = \&DBD::Multiplex::dump_handle;
for (sort keys %{ $DBI::DBI_methods{st} }) {
    next if defined &$_; # we have defined our own
    next if $do_not_mx_method_st{$_};
    next if $_ =~ m/^fetch/;
    DBI->trace_msg("     installing \$sth->$_ method for DBD::Multiplex\n");
    *$_ = mx_method_closure_st($_, $call_super_method_first{$_})
}

######################################## 
# AUTOLOAD to catch methods not explictly handled elsewhere,
# including driver-specific methods, and multiplex via func
# XXX using func isn't quite right, integrate with install_method/can?
########################################

sub AUTOLOAD {
    my $method = $DBD::Multiplex::st::AUTOLOAD;
    $method =~ s/^DBD::Multiplex::st:://;
    $_[0]->trace_msg("    mx AUTOLOAD \$sth->$method via func()\n");
    # do last to propagate list/scalar context
    return DBD::Multiplex::mx_method_all('func', @_, $method);
}


} #========================================================= END STATEMENT ===

1;

__END__

=head1 NAME

DBD::Multiplex - A multiplexing driver for the DBI.

=head1 SYNOPSIS

 use strict;

 use DBI;

 my ($dsn1, $dsn2, $dsn3, $dsn4, %attr);

 # Define four databases, in this case, four Postgres databases.
 
 $dsn1 = 'dbi:Pg:dbname=aaa;host=10.0.0.1;mx_id=db-aaa-1';
 $dsn2 = 'dbi:Pg:dbname=bbb;host=10.0.0.2;mx_id=db-bbb-2';
 $dsn3 = 'dbi:Pg:dbname=ccc;host=10.0.0.3;mx_id=db-ccc-3';
 $dsn4 = 'dbi:Pg:dbname=ddd;host=10.0.0.4;mx_id=db-ddd-4';

 # Define a callback error handler.
 
 sub MyErrorProcedure {
	my ($dsn, $mx_id, $error_number, $error_string, $h) = @_;
	open TFH, ">>/tmp/dbi_mx$mx_id.txt";
	print TFH localtime().": $error_number\t$error_string\n";
	close TFH;
	return 1;
 }

 # Define the pool of datasources.
 
 %attr = (
	'mx_dsns' => [$dsn1, $dsn2, $dsn3, $dsn4],
	'mx_master_id' => 'db-aaa-1',
	'mx_connect_mode' => 'ignore_errors',
	'mx_exit_mode' => 'first_success',
	'mx_error_proc' => \&MyErrorProcedure,
 );

 # Connect to all four datasources.
 
 $dbh = DBI->connect("dbi:Multiplex:", 'username', 'password', \%attr); 

 # See the DBI module documentation for full details.

=head1 DESCRIPTION

DBD::Multiplex is a Perl module which works with the DBI allowing you
to work with multiple datasources using a single DBI handle.

Basically, DBD::Multiplex database and statement handles are parents
that contain multiple child handles, one for each datasource. Method
calls on the parent handle trigger corresponding method calls on
each of the children.

One use of this module is to mirror the contents of one datasource
using a set of alternate datasources.  For that scenario it can
write to all datasources, but read from only from one datasource.

Alternatively, where a database already supports replication,
DBD::Multiplex can be used to direct writes to the master and spread
the selects across multiple slaves.

Another use for DBD::Multiplex is to simplify monitoring and
management of a large number of databases, especially when combined
with DBI::Shell.

=head1 COMPATIBILITY

A goal of this module is to be compatible with DBD::Proxy / DBI::ProxyServer.
Currently, the 'mx_error_proc' feature generates errors regarding the storage
of CODE references within the Storable module used by RPC::PlClient
which in turn is used by DBD::Proxy. Yet it works.

=head1 CONNECTING TO THE DATASOURCES

Multiple datasources are specified in the either the DSN parameter of
the DBI->connect() function (separated by the '|' character), 
or in the 'mx_dsns' key/value pair (as an array reference) of 
the \%attr hash parameter.

=head1 SPECIFIC ATTRIBUTES

The following specific attributes can be set when connecting:

=over 4

=item B<mx_dsns>

An array reference of DSN strings. 

=item B<mx_master_id>

Specifies which mx_id will be used as the master server for a
master/slave one-way replication scheme.

=item B<mx_connect_mode>

Options available or under consideration:

B<report_errors>

A failed connection to any of the data sources will generate a DBI error.
This is the default.

B<ignore_errors>

Failed connections are ignored, forgotten, and therefore, unused.

=item B<mx_exit_mode>

Options available or under consideration:
 
B<first_error>

Execute the requested method against each child handle, stopping 
after the first error, and returning the all of the results.
This is the default.

B<first_success>

Execute the requested method against each child handle, stopping after 
the first successful result, and returning only the successful result.
Most appropriate when reading from a set of mirrored datasources.

B<last_result>

Execute the requested method against each child handle, not stopping after 
any errors, and returning all of the results.

B<last_result_most_common>

Execute the requested method against each child handle, not stopping after 
the errors, and returning the most common result (eg three-way-voting etc).
Not yet implemented.

=item B<mx_shuffle>

Shuffles the list of child handles each time it's about to be used.
Typically combined with an C<mx_exit_mode> of 'C<first_success>'.

=item B<mx_shuffle_connect>

Like C<mx_shuffle> above but only applies to connect().

=item B<mx_error_proc>

A reference to a subroutine which will be executed whenever a DBI method 
generates an error when working with a specific datasource. It will be 
passed the DSN and 'mx_id' of the datasource, and the $DBI::err and $DBI::errstr.

Define your own subroutine and pass a reference to it. A simple
subroutine that just prints the dsn, mx_id, and error details to STDERR
can be selected by setting mx_error_proc to the string 'DEFAULT'.

=back

In some cases, the exit mode will depend on the method being called.
For example, this module will always execute $dbh->disconnect() calls 
against each child handle.
 
In others, the default will be used, unless the user of the DBI  
specified the 'mx_exit_mode' when connecting, or later changed 
the 'mx_exit_mode' attribute of a database or statement handle. 

=head1 USAGE EXAMPLE

Here's an example of using DBD::Multiplex with MySQL's replication scheme. 

MySQL supports one-way replication, which means we run a server as the master 
server and others as slaves which catch up any changes made on the master. 
Any READ operations then may be distributed among them (master and slave(s)), 
whereas any WRITE operation must I<only> be directed toward the master. 
Any changes happened on slave(s) will never get synchronized to other servers. 
More detailed instructions on how to arrange such setup can be found at:

http://www.mysql.com/documentation/mysql/bychapter/manual_Replication.html

Now say we have two servers, one at 10.0.0.1 as a master, and one at 
10.0.0.9 as a slave. The DSN for each server may be written like this:

 my @dsns = qw{
	dbi:mysql:database=test;host=10.0.0.1;mx_id=masterdb
	dbi:mysql:database=test;host=10.0.0.9;mx_id=slavedb
 };

Here we choose easy-to-remember C<mx_id>s: masterdb and slavedb.
You are free to choose alternative names, for example: mst and slv. 
Then we create the DSN for DBD::Multiplex by joining them, using the 
pipe character as separator:

 my $dsn = 'dbi:Multiplex:' . join('|', @dsns);
 my $user = 'username';
 my $pass = 'password';

As a more paranoid practice, configure the 'user's permissions to
allow only SELECTs on the slaves.

Next, we define the attributes which will affect DBD::Multiplex behaviour:

 my %attr = (
	'mx_master_id' => 'masterdb',
	'mx_exit_mode' => 'first_success',
	'mx_shuffle'    => 1,
 );

These attributes are required for MySQL replication support:

We set C<mx_shuffle> true which will make DBD::Multiplex shuffle the
DSN list order prior to connect, and shuffle the 

The C<mx_master_id> attribute specifies which C<mx_id> will be recognized
as the master. In our example, this is set to 'masterdb'. This attribute will
ensure that every WRITE operation will be executed only on the master server.
Finally, we call DBI->connect():

 $dbh = DBI->connect($dsn, $user, $pass, \%attr) or die $DBI::errstr;

=head1 LIMITATIONS AND BUGS

A HandleError sub is only invoked on the multiplex handle, not the
child handles and can't alter the return value.

The Name attribute may change in content in future versions.

The AutoCommit attribute doesn't appear to be affected by the begin_work
method. That's one symptom of the next item:

Attributes may not behave as expected because the DBI intercepts
attribute FETCH calls and returns the value, if there is one, from
DBD::Multiplex's attribute cache and doesn't give DBD::Multiplex a
change to multiplex the FETCH. That's fixed from DBI 1.36.

=head1 AUTHORS AND COPYRIGHT

Copyright (c) 1999,2000,2003, Tim Bunce & Thomas Kishel

While I defer to Tim Bunce regarding the majority of this module,
feel free to contact me for more information:

	Thomas Kishel
	Larson Texts, Inc.
	1760 Norcross Road
	Erie, PA 16510
	tkishel@tdlc.com
	814-461-8900

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
