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

use base qw(Exporter);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

our @EXPORT_OK = qw(
    execute_request
    execute_dbh_request
    execute_sth_request
);

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
    # what driver-specific attributes should be returned for the driver being used?
    # keyed by $dbh->{Driver}{Name}
    # XXX for dbh attr only need to be returned on first access by client
    # the client should then cache them. So need a way to indicate that.
    # XXX for sth should split into attr specific to resultsets (where NUM_OF_FIELDS > 0) and others
    # which would reduce processing/traffic for non-select statements
    mysql  => {
        dbh => [qw(
        )],
        sth => [qw(
            mysql_is_blob mysql_is_key mysql_is_num mysql_is_pri_key mysql_is_auto_increment
            mysql_length mysql_max_length mysql_table mysql_type mysql_type_name
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
            syb_types syb_result_type syb_proc_status
        )],
    },
);

my %extra_sth_attr = (
    # what driver-specific attributes should be returned for the driver being used?
    # keyed by $dbh->{Driver}{Name}
    # XXX could split into attr specific to resultsets (where NUM_OF_FIELDS > 0) and others
    # which would reduce processing/traffic for non-select statements
    mysql  => [qw(
        mysql_is_blob mysql_is_key mysql_is_num mysql_is_pri_key mysql_is_auto_increment
        mysql_length mysql_max_length mysql_table mysql_type mysql_type_name
    )],
    Pg  => [qw(
        pg_size pg_type pg_oid_status pg_cmd_status
    )],
    Sybase => [qw(
        syb_types syb_result_type syb_proc_status
    )],
);

our $trace = $ENV{DBI_GOFER_TRACE};

our $recurse = 0;

# XXX tracing

sub _connect {
    my $request = shift;

    local $ENV{DBI_AUTOPROXY}; # limit the insanity

    my $connect_args = $request->connect_args;
    my ($dsn, $u, $p, $attr) = @$connect_args;
    # delete attributes we don't want to affect the server-side
    delete @{$attr}{qw(Profile InactiveDestroy Warn HandleError HandleSetErr TraceLevel Taint TaintIn TaintOut)};
    my $connect_method = 'connect_cached';
    #$connect_method = 'connect';

    # XXX need way to limit/purge connect cache over time
    my $dbh = DBI->$connect_method($dsn, $u, $p, {
        %$attr,
        # force some attributes the way we want them
        PrintWarn  => 0,
        PrintError => 0,
        RaiseError => 1,
        # ensure this connect_cached doesn't have the same args as the client
        # because that causes subtle issues if in the same process (ie transport=null)
        dbi_go_execute_unique => 42+$recurse+rand(),
    });
    die "NOT CONNECTED" if $dbh and not $dbh->{Active};
    #$dbh->trace(0);
    return $dbh;
}


sub _reset_dbh {
    my ($dbh) = @_;
    $dbh->set_err(undef, undef); # clear any error state
}


sub _new_response_with_err {
    my ($rv) = @_;

    my ($err, $errstr, $state) = ($DBI::err, $DBI::errstr, $DBI::state);

    # if we caught an exception and there's either no DBI error, or the
    # exception itself doesn't look like a DBI exception, then append the
    # exception to errstr
    if ($@ and !$errstr || $@ !~ /^DBD::/) {
        $err ||= 1;
        $errstr = ($errstr) ? "$errstr; $@" : $@;
    }

    my $response = DBI::Gofer::Response->new({
        rv     => $rv,
        err    => $err,
        errstr => $errstr,
        state  => $state,
    });

    return $response;
}


sub execute_request {
    my $request = shift;
    local $recurse = $recurse + 1;
    warn "Gofer request level $recurse\n" if $trace;
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    # guaranteed not to throw an exception
    my $response = eval {
        ($request->is_sth_request)
            ? execute_sth_request($request)
            : execute_dbh_request($request);
    };
    if ($@) {
        chomp $@;
        $response = DBI::Gofer::Response->new({
            err => 1, errstr => $@, state  => '',
        });
    }
    #warn "Gofer response level $recurse: ".$response->rv."\n" if $trace;
    $response->warnings(\@warnings) if @warnings;
    return $response;
}


sub execute_dbh_request {
    my $request = shift;
    my $dbh;
    my $rv_ref = eval {
        $dbh = _connect($request);
        my $meth = $request->dbh_method_name;
        my $args = $request->dbh_method_args;
        my @rv = ($request->dbh_wantarray)
            ?        $dbh->$meth(@$args)
            : scalar $dbh->$meth(@$args);
        \@rv;
    };
    my $response = _new_response_with_err($rv_ref);
    if ($dbh) {
        $response->last_insert_id = $dbh->last_insert_id( @{ $request->dbh_last_insert_id_args })
            if $rv_ref && $request->dbh_last_insert_id_args;
        _reset_dbh($dbh);
    }
    if ($rv_ref and UNIVERSAL::isa($rv_ref->[0],'DBI::st')) {
        my $rv = $rv_ref->[0];
        # dbh_method_call was probably a metadata method like table_info
        # that returns a statement handle, so turn the $sth into resultset
        $response->sth_resultsets( _gather_sth_resultsets($rv, $request) );
        $response->rv("(sth)");
    }
    return $response;
}


sub execute_sth_request {
    my $request = shift;
    my $dbh;
    my $sth;

    my $rv = eval {
        $dbh = _connect($request);

        my $meth = $request->dbh_method_name;
        my $args = $request->dbh_method_args;
        $sth = $dbh->$meth(@$args);
        my $last = '(sth)'; # a true value

        # execute methods on the sth, e.g., bind_param & execute
        for my $meth_call (@{ $request->sth_method_calls }) {
            my $method = shift @$meth_call;
            $last = $sth->$method(@$meth_call);
        }
        $last;
    };
    my $response = _new_response_with_err($rv);

    # even if the eval failed we still want to try to gather attribute values
    $response->sth_resultsets( _gather_sth_resultsets($sth, $request) ) if $sth;

    # XXX would be nice to be able to support streaming of results
    # which would reduce memory usage and latency for large results

    _reset_dbh($dbh) if $dbh;

    return $response;
}


sub _gather_sth_resultsets {
    my ($sth, $request) = @_;
    return eval {
        my $driver_name = $sth->{Database}{Driver}{Name};
        my $extra_sth_attr = $extra_sth_attr{$driver_name} || [];

        my $sth_attr = {};
        $sth_attr->{$_} = 1 for (@sth_std_attr, @$extra_sth_attr);

        # let the client add/remove sth atributes
        if (my $sth_result_attr = $request->sth_result_attr) {
            $sth_attr->{$_} = $sth_result_attr->{$_}
                for keys %$sth_result_attr;
        }

        my $rs_list = [];
        do {
            my $rs = fetch_result_set($sth, $sth_attr);
            push @$rs_list, $rs;
        } while $sth->more_results
             || $sth->{syb_more_results};

        $rs_list;
    };
}


sub fetch_result_set {
    my ($sth, $extra_sth_attr) = @_;
    my %meta;
    while ( my ($attr,$use) = each %$extra_sth_attr ) {
        next unless $use;
        my $v = eval { $sth->FETCH($attr) };
        warn $@ if $@;
        $meta{ $attr } = $v if defined $v;
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

1;
