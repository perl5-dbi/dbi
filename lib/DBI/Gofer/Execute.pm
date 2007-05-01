package DBI::Gofer::Execute;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;
use warnings;

use DBI;
use DBI::Gofer::Request;
use DBI::Gofer::Response;

use base qw(DBI::Util::_accessor);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

our @all_dbh_methods = sort map { keys %$_ } $DBI::DBI_methods{db}, $DBI::DBI_methods{common};
our %all_dbh_methods = map { $_ => DBD::_::db->can($_) } @all_dbh_methods;

our $local_log = $ENV{DBI_GOFER_LOCAL_LOG}; # do extra logging to stderr

our $current_dbh;   # the dbh we're using for this request


# set trace for server-side gofer
# Could use DBI_TRACE env var when it's an unrelated separate process
# but using DBI_GOFER_TRACE makes testing easier for subprocesses (eg stream)
DBI->trace(split /=/, $ENV{DBI_GOFER_TRACE}, 2) if $ENV{DBI_GOFER_TRACE};


__PACKAGE__->mk_accessors(qw(
    check_request
    default_connect_dsn
    forced_connect_dsn
    default_connect_attributes
    forced_connect_attributes
    forced_single_resultset
    max_cached_dbh_per_drh
    max_cached_sth_per_dbh
    track_recent
    stats
)); 


sub new {
    my ($self, $args) = @_;
    $args->{default_connect_attributes} ||= {};
    $args->{forced_connect_attributes}  ||= {};
    $args->{max_cached_sth_per_dbh}     ||= 1000;
    $args->{stats} ||= {};
    return $self->SUPER::new($args);
}


my @sth_std_attr = qw(
    NUM_OF_PARAMS
    NUM_OF_FIELDS
    NAME
    TYPE
    NULLABLE
    PRECISION
    SCALE
);

my %extra_attr = (
    # Only referenced if the driver doesn't support private_attribute_info method.
    # what driver-specific attributes should be returned for the driver being used?
    # keyed by $dbh->{Driver}{Name}
    # XXX for sth should split into attr specific to resultsets (where NUM_OF_FIELDS > 0) and others
    # which would reduce processing/traffic for non-select statements
    mysql  => {
        dbh => [qw(
            mysql_errno mysql_error mysql_hostinfo mysql_info mysql_insertid
            mysql_protoinfo mysql_serverinfo mysql_stat mysql_thread_id
        )],
        sth => [qw(
            mysql_is_blob mysql_is_key mysql_is_num mysql_is_pri_key mysql_is_auto_increment
            mysql_length mysql_max_length mysql_table mysql_type mysql_type_name mysql_insertid
        )],
        # XXX this dbh_after_sth stuff is a temporary, but important, hack.
        # should be done via hash instead of arrays where the hash value contains
        # flags that can indicate which attributes need to be handled in this way
        dbh_after_sth => [qw(
            mysql_insertid
        )],
    },
    Pg  => {
        dbh => [qw(
            pg_protocol pg_lib_version pg_server_version
            pg_db pg_host pg_port pg_default_port
            pg_options pg_pid
        )],
        sth => [qw(
            pg_size pg_type pg_oid_status pg_cmd_status
        )],
    },
    Sybase => {
        dbh => [qw(
            syb_dynamic_supported syb_oc_version syb_server_version syb_server_version_string
        )],
        sth => [qw(
            syb_types syb_proc_status syb_result_type
        )],
    },
    SQLite => {
        dbh => [qw(
            sqlite_version
        )],
        sth => [qw(
        )],
    },
);


sub _connect {
    my ($self, $request) = @_;

    my $stats = $self->{stats};

    # discard CachedKids from time to time
    if (++$stats->{_requests_served} % 1000 == 0 # XXX config?
        and my $max_cached_dbh_per_drh = $self->{max_cached_dbh_per_drh}
    ) {
        my %drivers = DBI->installed_drivers();
        while ( my ($driver, $drh) = each %drivers ) {
            next unless my $CK = $drh->{CachedKids};
            next unless keys %$CK > $max_cached_dbh_per_drh;
            next if $driver eq 'Gofer'; # ie transport=null when testing
            DBI->trace_msg(sprintf "Clearing %d cached dbh from $driver",
                scalar keys %$CK, $self->{max_cached_dbh_per_drh});
            $_->{Active} && $_->disconnect for values %$CK;
            %$CK = ();
        }
    }

    local $ENV{DBI_AUTOPROXY}; # limit the insanity

    my ($connect_method, $dsn, $username, $password, $attr) = @{ $request->dbh_connect_call };
    $connect_method ||= 'connect_cached';

    # delete attributes we don't want to affect the server-side
    # (Could just do this on client-side and trust the client. DoS?)
    delete @{$attr}{qw(Profile InactiveDestroy HandleError HandleSetErr TraceLevel Taint TaintIn TaintOut)};

    $dsn = $self->forced_connect_dsn || $dsn || $self->default_connect_dsn
        or die "No forced_connect_dsn, requested dsn, or default_connect_dsn for request";

    # XXX implement our own private connect_cached method? (with rate-limited ping)
    my $dbh = DBI->$connect_method($dsn, undef, undef, {

        # the configured default attributes, if any
        %{ $self->default_connect_attributes },

        # the requested attributes
        %$attr,

        # force some attributes the way we'd like them
        PrintWarn  => $local_log,
        PrintError => $local_log,

        # the configured default attributes, if any
        %{ $self->forced_connect_attributes },

        # RaiseError must be enabled
        RaiseError => 1,

        # reset Executed flag (of the cached handle) so we can use it to tell
        # if errors happened before the main part of the request was executed
        Executed => 0,

        # ensure this connect_cached doesn't have the same args as the client
        # because that causes subtle issues if in the same process (ie transport=null)
	# include pid to avoid problems with forking (ie null transport in mod_perl)
        dbi_go_execute_unique => __PACKAGE__."$$",
    });

    $dbh->{ShowErrorStatement} = 1 if $local_log;

    # note that this affects previously cached handles because $ENV{DBI_GOFER_RANDOM_FAIL}
    # isn't included in the cache key. Could add a go_rand_fail=>... attribute.
    $self->_install_rand_fail_callbacks($dbh, $ENV{DBI_GOFER_RANDOM_FAIL})
        if $ENV{DBI_GOFER_RANDOM_FAIL};

    my $CK = $dbh->{CachedKids};
    if ($CK && keys %$CK > $self->{max_cached_sth_per_dbh}) {
        %$CK = (); #  clear all statement handles
    }

    #$dbh->trace(0);
    $current_dbh = $dbh;
    return $dbh;
}


sub reset_dbh {
    my ($self, $dbh) = @_;
    $dbh->set_err(undef, undef); # clear any error state
}


sub new_response_with_err {
    my ($self, $rv, $eval_error, $dbh) = @_;
    # capture err+errstr etc and merge in $eval_error ($@)

    my ($err, $errstr, $state) = ($DBI::err, $DBI::errstr, $DBI::state);

    # if we caught an exception and there's either no DBI error, or the
    # exception itself doesn't look like a DBI exception, then append the
    # exception to errstr
    if ($eval_error and (!$errstr || $eval_error !~ /^DBD::/)) {
        chomp $eval_error;
        $err ||= 1;
        $errstr = ($errstr) ? "$errstr; $eval_error" : $eval_error;
    }

    my $flags;
    # (XXX if we ever add transaction support then we'll need to take extra
    # steps because the commit/rollback would reset Executed before we get here)
    $flags |= GOf_RESPONSE_EXECUTED if $dbh && $dbh->{Executed};

    my $response = DBI::Gofer::Response->new({
        rv     => $rv,
        err    => $err,
        errstr => $errstr,
        state  => $state,
        flags  => $flags,
    });

    return $response;
}


sub execute_request {
    my ($self, $request) = @_;
    # should never throw an exception

    DBI->trace_msg("-----> execute_request\n");

    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_; warn @_ if $local_log };

    my $response = eval {

        if (my $check_request = $self->check_request) {
            $request = $check_request->($request)
                or die "check_request failed";
        }

        my $version = $request->version || 0;
        die ref($request)." version $version is not supported"
            if $version < 0.009116 or $version >= 1;

        ($request->is_sth_request)
            ? $self->execute_sth_request($request)
            : $self->execute_dbh_request($request);
    };
    $response ||= $self->new_response_with_err(undef, $@, $current_dbh);
    undef $current_dbh;

    $response->warnings(\@warnings) if @warnings;
    DBI->trace_msg("<----- execute_request\n");
    return $response;
}


sub execute_dbh_request {
    my ($self, $request) = @_;
    my $stats = $self->{stats};

    my $dbh;
    my $rv_ref = eval {
        $dbh = $self->_connect($request);
        my $args = $request->dbh_method_call; # [ 'method_name', @args ]
        my $wantarray = shift @$args;
        my $meth      = shift @$args;
        $stats->{method_calls_dbh}->{$meth}++;
        my @rv = ($wantarray)
            ?        $dbh->$meth(@$args)
            : scalar $dbh->$meth(@$args);
        \@rv;
    } || [];
    my $response = $self->new_response_with_err($rv_ref, $@, $dbh);

    return $response if not $dbh;

    # does this request also want any dbh attributes returned?
    if (my $dbh_attributes = $request->dbh_attributes) {
        $response->dbh_attributes( $self->gather_dbh_attributes($dbh, $dbh_attributes) );
    }

    if ($rv_ref and my $lid_args = $request->dbh_last_insert_id_args) {
        $stats->{method_calls_dbh}->{last_insert_id}++;
        my $id = $dbh->last_insert_id( @$lid_args );
        $response->last_insert_id( $id );
    }

    if ($rv_ref and UNIVERSAL::isa($rv_ref->[0],'DBI::st')) {
        # dbh_method_call was probably a metadata method like table_info
        # that returns a statement handle, so turn the $sth into resultset
        my $sth = $rv_ref->[0];
        $response->sth_resultsets( $self->gather_sth_resultsets($sth, $request, $response) );
        $response->rv("(sth)"); # don't try to return actual sth
    }

    # we're finished with this dbh for this request
    $self->reset_dbh($dbh);

    return $response;
}


sub gather_dbh_attributes {
    my ($self, $dbh, $dbh_attributes) = @_;
    my @req_attr_names = @$dbh_attributes;
    if ($req_attr_names[0] eq '*') { # auto include std + private
        shift @req_attr_names;
        push @req_attr_names, @{ $self->_get_std_attributes($dbh) };
    }
    my %dbh_attr_values;
    $dbh_attr_values{$_} = $dbh->FETCH($_) for @req_attr_names;

    # XXX piggyback installed_methods onto dbh_attributes for now
    $dbh_attr_values{dbi_installed_methods} = { DBI->installed_methods };
    
    # XXX piggyback default_methods onto dbh_attributes for now
    $dbh_attr_values{dbi_default_methods} = _get_default_methods($dbh);
    
    return \%dbh_attr_values;
}


sub _get_std_attributes {
    my ($self, $h) = @_;
    $h = tied(%$h) || $h; # switch to inner handle
    my $attr_names = $h->{private_gofer_std_attr_names};
    return $attr_names if $attr_names;
    # add some extra because drivers may have different defaults
    # add Name so the client gets the real Name of the connection
    my @attr_names = qw(ChopBlanks LongReadLen LongTruncOk ReadOnly Name);
    if (my $pai = $h->private_attribute_info) {
        push @attr_names, keys %$pai;
    }
    elsif (my $drh = $h->{Driver}) { # is a dbh
        push @attr_names, @{ $extra_attr{ $drh->{Name} }{dbh} || []};
    }
    elsif ($drh = $h->{Driver}{Database}) { # is an sth
        push @attr_names, @{ $extra_attr{ $drh->{Name} }{sth} || []};
    }
    return $h->{private_gofer_std_attr_names} = \@attr_names;
}


sub execute_sth_request {
    my ($self, $request) = @_;
    my $dbh;
    my $sth;
    my $last_insert_id;
    my $stats = $self->{stats};

    my $rv = eval {
        $dbh = $self->_connect($request);

        my $args = $request->dbh_method_call; # [ wantarray, 'method_name', @args ]
        shift @$args; # discard wantarray
        my $meth = shift @$args;
        $stats->{method_calls_sth}->{$meth}++;
        $sth = $dbh->$meth(@$args);
        my $last = '(sth)'; # a true value (don't try to return actual sth)

        # execute methods on the sth, e.g., bind_param & execute
        if (my $calls = $request->sth_method_calls) {
            for my $meth_call (@$calls) {
                my $method = shift @$meth_call;
                $stats->{method_calls_sth}->{$method}++;
                $last = $sth->$method(@$meth_call);
            }
        }

        if (my $lid_args = $request->dbh_last_insert_id_args) {
            $stats->{method_calls_sth}->{last_insert_id}++;
            $last_insert_id = $dbh->last_insert_id( @$lid_args );
        }

        $last;
    };
    my $response = $self->new_response_with_err($rv, $@, $dbh);

    return $response if not $dbh;

    $response->last_insert_id( $last_insert_id )
        if defined $last_insert_id;

    # even if the eval failed we still want to try to gather attribute values
    # (XXX would be nice to be able to support streaming of results.
    # which would reduce memory usage and latency for large results)
    if ($sth) {
        $response->sth_resultsets( $self->gather_sth_resultsets($sth, $request, $response) );
        $sth->finish;
    }

    # does this request also want any dbh attributes returned?
    my $dbh_attr_set;
    if (my $dbh_attributes = $request->dbh_attributes) {
        $dbh_attr_set = $self->gather_dbh_attributes($dbh, $dbh_attributes);
    }
    if (my $dbh_attr = $extra_attr{$dbh->{Driver}{Name}}{dbh_after_sth}) {
        $dbh_attr_set->{$_} = $dbh->FETCH($_) for @$dbh_attr;
    }
    $response->dbh_attributes($dbh_attr_set) if $dbh_attr_set && %$dbh_attr_set;

    $self->reset_dbh($dbh);

    return $response;
}


sub gather_sth_resultsets {
    my ($self, $sth, $request, $response) = @_;
    my $resultsets = eval {
        my $driver_name = $sth->{Database}{Driver}{Name};
        my $extra_sth_attr = $extra_attr{$driver_name}{sth} || [];

        my $sth_attr = {};
        $sth_attr->{$_} = 1 for (@sth_std_attr, @$extra_sth_attr);

        # let the client add/remove sth atributes
        if (my $sth_result_attr = $request->sth_result_attr) {
            $sth_attr->{$_} = $sth_result_attr->{$_}
                for keys %$sth_result_attr;
        }

        my $row_count = 0;
        my $rs_list = [];
        do {
            my $rs = $self->fetch_result_set($sth, $sth_attr);
            push @$rs_list, $rs;
            if (my $rows = $rs->{rowset}) {
                $row_count += @$rows;
            }
            last if $self->{forced_single_resultset};
        } while $sth->more_results
             || $sth->{syb_more_results};

        my $stats = $self->{stats};
        $stats->{rows_returned_total} += $row_count;
        $stats->{rows_returned_max} = $row_count
            if $row_count > ($stats->{rows_returned_max}||0);

        $rs_list;
    };
    $response->add_err(1, $@) if $@;
    return $resultsets;
}


sub fetch_result_set {
    my ($self, $sth, $extra_sth_attr) = @_;
    my %meta;
    while ( my ($attr,$use) = each %$extra_sth_attr ) {
        next unless $use;
        my $v = eval { $sth->FETCH($attr) };
        if (defined $v) {
            $meta{ $attr } = $v;
        }
        else {
            warn $@ if $@;
        }
    }
    my $NUM_OF_FIELDS = $meta{NUM_OF_FIELDS};
    $NUM_OF_FIELDS = $sth->FETCH('NUM_OF_FIELDS') unless defined $NUM_OF_FIELDS;
    if ($NUM_OF_FIELDS) { # is a select
        $meta{rowset} = eval { $sth->fetchall_arrayref() };
        $meta{err}    = $DBI::err;
        $meta{errstr} = $DBI::errstr;
        $meta{state}  = $DBI::state;
    }
    return \%meta;
}


sub _get_default_methods {
    my ($dbh) = @_;
    # returns a ref to a hash of dbh method names for methods which the driver
    # hasn't overridden i.e., quote(). These don't need to be forwarded via gofer.
    my $ImplementorClass = $dbh->{ImplementorClass} or die;
    my %default_methods;
    for my $method (@all_dbh_methods) {
        my $dbi_sub = $all_dbh_methods{$method}       || 42;
        my $imp_sub = $ImplementorClass->can($method) || 42;
        next if $imp_sub != $dbi_sub;
        #warn("default $method\n");
        $default_methods{$method} = 1;
    }
    return \%default_methods;
}


sub _install_rand_fail_callbacks {
    my ($self, $dbh, $dbi_gofer_random_fail) = @_;
    my ($rand_fail_freq, @rand_fail_methods) = split /,/, $dbi_gofer_random_fail;
    @rand_fail_methods = qw(do prepare) if !@rand_fail_methods; # only works for dbh methods
    if ($rand_fail_freq) {
        warn "DBI_GOFER_RANDOM_FAIL set to '$ENV{DBI_GOFER_RANDOM_FAIL}' "
            ."so random failures will be generated! "
            ."(approx 1-in-$rand_fail_freq calls for methods: @rand_fail_methods)\n";
        my $callbacks = $dbh->{Callbacks} || {};
        my $prev      = $dbh->{private_gofer_rand_fail_callbacks} || {};
        for my $method (@rand_fail_methods) {
            if ($callbacks->{$method} && $callbacks->{$method} != $prev->{$method}) {
                warn "Callback for $method method already installed so DBI_GOFER_RANDOM_FAIL callback not installed\n";
                next;
            }
            $callbacks->{$method} = $self->_mk_rand_fail_sub($rand_fail_freq, $method);
        }
        $dbh->{Callbacks} = $callbacks;
        $dbh->{private_gofer_rand_fail_callbacks} = $callbacks;
    }
}

sub _mk_rand_fail_sub {
    my ($self, $rand_fail_freq, $method) = @_;
    # $method may be "*"
    return sub {
        my $rand = rand();
        #warn sprintf "DBI_GOFER_RANDOM_FAIL($rand_fail_freq) %f - %f\n", $rand, 1/$rand_fail_freq;
        return if $rand > 1/$rand_fail_freq;
        undef $_; # tell DBI to not call the method
        return $_[0]->set_err(1, "fake error induced by DBI_GOFER_RANDOM_FAIL env var");
    }
}


1;
__END__

=head1 NAME

DBI::Gofer::Execute - Executes Gofer requests and returns Gofer responses

=head1 SYNOPSIS

  $executor = DBI::Gofer::Execute->new( { ...config... });

  $response = $executor->execute_request( $request );

=head1 DESCRIPTION

Accepts a DBI::Gofer::Request object, executes the requested DBI method calls,
and returns a DBI::Gofer::Response object.

Any error, including any internal 'fatal' errors are caught and converted into
a DBI::Gofer::Response object.

=head1 CONFIGURATION

=head2 check_request

If defined, it must be a reference to a subroutine that will 'check' the request.

The subroutine can either return the original request object or die with a
suitable error message (which will be turned into a Gofer response).

It can also construct and return a new request that should be executed instead
of the original request.

=head2 forced_connect_dsn

If set, this DSN is always used instead of the one in the request.

=head2 default_connect_dsn

If set, this DSN is used if C<forced_connect_dsn> is not set and the request does not contain a DSN.

=head2 forced_connect_attributes

A reference to a hash of connect() attributes. Individual attributes in
C<forced_connect_attributes> will take precedence over corresponding attributes
in the request.

=head2 default_connect_attributes

A reference to a hash of connect() attributes. Individual attributes in the
request take precedence over corresponding attributes in C<default_connect_attributes>.

=head2 max_cached_dbh_per_drh

If set, the loaded drivers will be checked to ensure they don't have more than
this number of cached connections. There is no default value. This limit is not
enforced for every request.

=head2 max_cached_sth_per_dbh

If set, all the cached statement handles will be cleared once the number of
cached statement handles rises above this limit. The default is 1000.

=head2 forced_single_resultset

If true, then only a single result set will be fetched and returned in the response.

=head2 track_recent

If set, specifies the number of recent requests and responses that (the
transport) should keep for diagnostics. See L<DBI::Gofer::Transport::mod_perl>
Note that this setting can significantly increase memory use.

=head1 TO DO

Currently every 1000 requests all the cached dbh are disconnected cleared to avoid
the connection and statement handle caches growing too large. A smarter system is needed.

=head1 AUTHOR AND COPYRIGHT

The DBD::Gofer, DBD::Gofer::* and DBI::Gofer::* modules are
Copyright (c) 2007 Tim Bunce. Ireland.  All rights reserved.

You may distribute under the terms of either the GNU General Public License or
the Artistic License, as specified in the Perl README file.

