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

__PACKAGE__->mk_accessors(qw(
    check_connect
    default_connect_dsn
    forced_connect_dsn
    default_connect_attributes
    forced_connect_attributes
    requests_served_count
)); 


sub new {
    my ($self, $args) = @_;
    $args->{default_connect_attributes} ||= {};
    $args->{forced_connect_attributes}  ||= {};
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
    # what driver-specific attributes should be returned for the driver being used?
    # Only referenced if the driver doesn't support private_attribute_info method.
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


# set trace for server-side gofer
# Could use DBI_TRACE env var when it's a separate process
# but using DBI_GOFER_TRACE makes testing easier (e.g., with null transport)
DBI->trace(split /=/, $ENV{DBI_GOFER_TRACE}, 2) if $ENV{DBI_GOFER_TRACE};


sub _connect {
    my ($self, $request) = @_;

    # just a quick hack for now
    if (++$self->{request_count} % 1000 == 0) { # XXX config
        # discard CachedKids from time to time
        my %drivers = DBI->installed_drivers();
        while ( my ($driver, $drh) = each %drivers ) {
            next if $driver eq 'Gofer'; # ie transport=null when testing
            next unless my $CK = $drh->{CachedKids};
            # XXX currently we discard all regardless
            # because that avoids the need to also handle
            # limiting the prepared statement cache
            my $cached_dbh_count = keys %$CK;
            #next unless $cached_dbh_count > 20; # XXX config

            DBI->trace_msg("Clearing $cached_dbh_count cached dbh from $driver");
            $_->{Active} && $_->disconnect for values %$CK;
            %$CK = ();
        }
    }

    my ($dsn, $attr) = @{ $request->connect_args };
    # delete attributes we don't want to affect the server-side
    # (Could just do this on client-side and trust the client. DoS?)
    delete @{$attr}{qw(Profile InactiveDestroy HandleError HandleSetErr TraceLevel Taint TaintIn TaintOut)};
    my $connect_method = 'connect_cached';

    my $check_connect = $self->check_connect;
    $check_connect->($dsn, $attr, $connect_method, $request) if $check_connect;

    $dsn = $self->forced_connect_dsn || $dsn || $self->default_connect_dsn
        or die "No forced_connect_dsn, requested dsn, or default_connect_dsn for request";

    local $ENV{DBI_AUTOPROXY}; # limit the insanity

    # XXX implement our own private connect_cached method?
    my $dbh = DBI->$connect_method($dsn, undef, undef, {

        # the configured default attributes, if any
        %{ $self->default_connect_attributes },

        # the requested attributes
        %$attr,

        # force some attributes the way we'd like them
        PrintWarn  => 0,
        PrintError => 0,

        # the configured default attributes, if any
        %{ $self->forced_connect_attributes },

        # RaiseError must be enabled
        RaiseError => 1,

        # ensure this connect_cached doesn't have the same args as the client
        # because that causes subtle issues if in the same process (ie transport=null)
        dbi_go_execute_unique => __PACKAGE__,
    });
    #$dbh->trace(0);
    return $dbh;
}


sub reset_dbh {
    my ($self, $dbh) = @_;
    $dbh->set_err(undef, undef); # clear any error state
}


sub new_response_with_err {
    my ($self, $rv, $eval_error) = @_;
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

    my $response = DBI::Gofer::Response->new({
        rv     => $rv,
        err    => $err,
        errstr => $errstr,
        state  => $state,
    });

    return $response;
}


sub execute_request {
    my ($self, $request) = @_;
    # should never throw an exception
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    DBI->trace_msg("-----> execute_request\n");

    my $response = eval {

        my $version = $request->version || 0;
        die ref($request)." version $version is not supported"
            if $version < 0.009116 or $version >= 1;

        ($request->is_sth_request)
            ? $self->execute_sth_request($request)
            : $self->execute_dbh_request($request);
    };
    $response = $self->new_response_with_err(undef, $@)
        if $@;

    $response->warnings(\@warnings) if @warnings;
    DBI->trace_msg("<----- execute_request\n");
    return $response;
}


sub execute_dbh_request {
    my ($self, $request) = @_;

    my $dbh;
    my $rv_ref = eval {
        $dbh = $self->_connect($request);
        my $args = $request->dbh_method_call; # [ 'method_name', @args ]
        my $meth = shift @$args;
        my @rv = ($request->dbh_wantarray)
            ?        $dbh->$meth(@$args)
            : scalar $dbh->$meth(@$args);
        \@rv;
    };
    my $response = $self->new_response_with_err($rv_ref, $@);

    return $response if not $dbh;

    # does this request also want any dbh attributes returned?
    if (my $dbh_attributes = $request->dbh_attributes) {
        my @req_attr_names = @$dbh_attributes;
        if ($req_attr_names[0] eq '*') { # auto include std + private
            shift @req_attr_names;
            push @req_attr_names, @{ $self->_get_std_attributes($dbh) };
        }
        my %dbh_attr_values;
        $dbh_attr_values{$_} = $dbh->FETCH($_) for @req_attr_names;
        $response->dbh_attributes(\%dbh_attr_values);
    }

    if ($rv_ref and my $lid_args = $request->dbh_last_insert_id_args) {
        my $id = $dbh->last_insert_id( @$lid_args );
        $response->last_insert_id( $id );
    }

    if ($rv_ref and UNIVERSAL::isa($rv_ref->[0],'DBI::st')) {
        # dbh_method_call was probably a metadata method like table_info
        # that returns a statement handle, so turn the $sth into resultset
        my $rv = $rv_ref->[0];
        $response->sth_resultsets( $self->gather_sth_resultsets($rv, $request) );
        $response->rv("(sth)"); # don't try to return actual sth
    }

    # we're finished with this dbh for this request
    $self->reset_dbh($dbh);

    return $response;
}


sub _get_std_attributes {
    my ($self, $h) = @_;
    $h = tied(%$h) || $h; # switch to inner handle
    my $attr_names = $h->{private_gofer_std_attr_names};
    return $attr_names if $attr_names;
    # add ChopBlanks LongReadLen LongTruncOk because drivers may have different defaults
    # plus Name so the client gets the real Name of the connection
    my @attr_names = qw(ChopBlanks LongReadLen LongTruncOk Name);
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

    my $rv = eval {
        $dbh = $self->_connect($request);

        my $args = $request->dbh_method_call; # [ 'method_name', @args ]
        my $meth = shift @$args;
        $sth = $dbh->$meth(@$args);
        my $last = '(sth)'; # a true value (don't try to return actual sth)

        # execute methods on the sth, e.g., bind_param & execute
        if (my $calls = $request->sth_method_calls) {
            for my $meth_call (@$calls) {
                my $method = shift @$meth_call;
                $last = $sth->$method(@$meth_call);
            }
        }

        if (my $lid_args = $request->dbh_last_insert_id_args) {
            $last_insert_id = $dbh->last_insert_id( @$lid_args );
        }

        $last;
    };
    my $response = $self->new_response_with_err($rv, $@);

    $response->last_insert_id( $last_insert_id ) if defined $last_insert_id;

    # even if the eval failed we still want to try to gather attribute values
    $response->sth_resultsets( $self->gather_sth_resultsets($sth, $request) ) if $sth;

    # XXX would be nice to be able to support streaming of results
    # which would reduce memory usage and latency for large results

    $self->reset_dbh($dbh) if $dbh;

    return $response;
}


sub gather_sth_resultsets {
    my ($self, $sth, $request) = @_;
    return eval {
        my $driver_name = $sth->{Database}{Driver}{Name};
        my $extra_sth_attr = $extra_attr{$driver_name}{sth} || [];

        my $sth_attr = {};
        $sth_attr->{$_} = 1 for (@sth_std_attr, @$extra_sth_attr);

        # let the client add/remove sth atributes
        if (my $sth_result_attr = $request->sth_result_attr) {
            $sth_attr->{$_} = $sth_result_attr->{$_}
                for keys %$sth_result_attr;
        }

        my $rs_list = [];
        do {
            my $rs = $self->fetch_result_set($sth, $sth_attr);
            push @$rs_list, $rs;
        } while $sth->more_results
             || $sth->{syb_more_results};

        $rs_list;
    };
}


sub fetch_result_set {
    my ($self, $sth, $extra_sth_attr) = @_;
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

=head1 AUTHOR AND COPYRIGHT

The DBD::Gofer, DBD::Gofer::* and DBI::Gofer::* modules are
Copyright (c) 2007 Tim Bunce. Ireland.  All rights reserved.

You may distribute under the terms of either the GNU General Public License or
the Artistic License, as specified in the Perl README file.

