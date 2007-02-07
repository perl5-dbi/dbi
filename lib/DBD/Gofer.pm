{
    package DBD::Gofer;

    use strict;

    require DBI;
    require DBI::Gofer::Request;
    require DBI::Gofer::Response;
    require Carp;

    our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.



    # attributes we'll allow local STORE
    our %xxh_local_store_attrib = map { $_=>1 } qw(
        Active
        CachedKids
        Callbacks
        ErrCount Executed
        FetchHashKeyName
        HandleError HandleSetErr
        InactiveDestroy
        PrintError PrintWarn
        Profile
        RaiseError
        RootClass
        ShowErrorStatement
        Taint TaintIn TaintOut
        TraceLevel
        Warn
        dbi_quote_identifier_cache
        dbi_connect_closure
        dbi_go_execute_unique
    );
    our %xxh_local_store_if_same_attrib = map { $_=>1 } qw(
        Username
        dbi_connect_method
    );

    our $drh = undef;	# holds driver handle once initialised
    our $methods_already_installed;

    sub driver{
	return $drh if $drh;

        DBI->setup_driver('DBD::Gofer');

        unless ($methods_already_installed++) {
            DBD::Gofer::db->install_method('go_dbh_method', { O=> 0x0004 }); # IMA_KEEP_ERR
            DBD::Gofer::st->install_method('go_sth_method', { O=> 0x0004 }); # IMA_KEEP_ERR
        }

	my($class, $attr) = @_;
	$class .= "::dr";
	($drh) = DBI::_new_drh($class, {
	    'Name' => 'Gofer',
	    'Version' => $VERSION,
	    'Attribution' => 'DBD Gofer by Tim Bunce',
        });

	$drh;
    }


    sub CLONE {
        undef $drh;
    }


    sub set_err_from_response {
        my ($h, $response) = @_;
        # set error/warn/info
        my $warnings = $response->warnings || [];
        warn $_ for @$warnings;
        return $h->set_err($response->err, $response->errstr, $response->state);
    }

}


{   package DBD::Gofer::dr; # ====== DRIVER ======

    my %dsn_attr_defaults = (
        go_dsn => undef,
        go_url => undef,
        go_transport => undef,
    );

    $imp_data_size = 0;
    use strict;

    sub connect {
        my($drh, $dsn, $user, $auth, $attr)= @_;
        my $orig_dsn = $dsn;

        # first remove dsn= and everything after it
        my $remote_dsn = ($dsn =~ s/\bdsn=(.*)$// && $1)
            or return $drh->set_err(1, "No dsn= argument in '$orig_dsn'");

        if ($attr->{go_bypass}) { # don't use DBD::Gofer for this connection
            # useful for testing with DBI_AUTOPROXY, e.g., t/03handle.t
            return DBI->connect($remote_dsn, $user, $auth, $attr);
        }

        my %dsn_attr = (%dsn_attr_defaults, go_dsn => $remote_dsn);
        # extract any go_ attributes from the connect() attr arg
        for my $k (grep { /^go_/ } keys %$attr) {
            $dsn_attr{$k} = delete $attr->{$k};
        }
        # then override those with any attributes embedded in our dsn (not remote_dsn)
        for my $kv (grep /=/, split /;/, $dsn, -1) {
            my ($k, $v) = split /=/, $kv, 2;
            $dsn_attr{ "go_$k" } = $v;
        }
        if (keys %dsn_attr > keys %dsn_attr_defaults) {
            delete @dsn_attr{ keys %dsn_attr_defaults };
            return $drh->set_err(1, "Unknown attributes: @{[ keys %dsn_attr ]}");
        }

        my $transport_class = delete $dsn_attr{go_transport}
            or return $drh->set_err(1, "No transport= argument in '$orig_dsn'");
        $transport_class = "DBD::Gofer::Transport::$transport_class"
            unless $transport_class =~ /::/;
        _load_class($transport_class)
            or return $drh->set_err(1, "Error loading $transport_class: $@");
        my $go_trans = eval { $transport_class->new(\%dsn_attr) }
            or return $drh->set_err(1, "Error instanciating $transport_class: $@");

        # XXX user/pass of fwd server vs db server
        my $request_class = "DBI::Gofer::Request";
        my $go_request = eval {
            # copy and delete any attributes we can't serialize (and don't want to)
            my $go_attr = { %$attr };
            delete @{$go_attr}{qw(Profile HandleError HandleSetErr Callbacks)};
            $request_class->new({
                connect_args => [ $remote_dsn, $user, $auth, $go_attr ]
            })
        } or return $drh->set_err(1, "Error instanciating $request_class $@");

        my ($dbh, $dbh_inner) = DBI::_new_dbh($drh, {
            'Name' => $dsn,
            'USER' => $user,
            go_trans => $go_trans,
            go_request => $go_request,
            go_policy => undef, # XXX
        });

        $dbh->STORE(Active => 0); # mark as inactive temporarily for STORE

        # test the connection XXX control via a policy later
        unless ($dbh->go_dbh_method('ping', undef)) {
            return undef if $dbh->err; # error already recorded, typically
            return $dbh->set_err(1, "ping failed");
        }
            # unless $policy->skip_connect_ping($attr, $dsn, $user, $auth, $attr);

        # Active not set until connected() called.

        return $dbh;
    }

    sub DESTROY { undef }


    sub _load_class { # return true or false+$@
        my $class = shift;
        (my $pm = $class) =~ s{::}{/}g;
        $pm .= ".pm";
        return 1 if eval { require $pm };
        delete $INC{$pm}; # shouldn't be needed (perl bug?) and assigning undef isn't enough
        undef; # error in $@
    }

}


{   package DBD::Gofer::db; # ====== DATABASE ======
    $imp_data_size = 0;
    use strict;
    use Carp qw(croak);

    my %dbh_local_store_attrib = %DBD::Gofer::xxh_local_store_attrib;

    sub connected {
        shift->STORE(Active => 1);
    }

    sub go_dbh_method {
        my ($dbh, $method, $meta, @args) = @_;
        my $request = $dbh->{go_request};
        $request->init_request($method, \@args, wantarray);

        my $transport = $dbh->{go_trans}
            or return $dbh->set_err(1, "Not connected (no transport)");

        eval { $transport->transmit_request($request) }
            or return $dbh->set_err(1, "transmit_request failed: $@");

        my $response = $transport->receive_response;
        my $rv = $response->rv;

        $dbh->{go_response} = $response;

        if (my $resultset_list = $response->sth_resultsets) {
            # setup an sth but don't execute/forward it
            my $sth = $dbh->prepare(undef, { go_skip_early_prepare => 1 }); # XXX
            # set the sth response to our dbh response
            (tied %$sth)->{go_response} = $response;
            # setup the set with the results in our response
            $sth->more_results;
            $rv = [ $sth ];
        }

        DBD::Gofer::set_err_from_response($dbh, $response);

        return (wantarray) ? @$rv : $rv->[0];
    }

    # Methods that should be forwarded
    # XXX get_info? special sub to lazy-cache individual values
    for my $method (qw(
        data_sources
        table_info column_info primary_key_info foreign_key_info statistics_info
        type_info_all get_info
        parse_trace_flags parse_trace_flag
        func
    )) {
        no strict 'refs';
        *$method = sub { return shift->go_dbh_method($method, undef, @_) }
    }

    # Methods that should always fail
    for my $method (qw(
        begin_work commit rollback
    )) {
        no strict 'refs';
        *$method = sub { return shift->set_err(1, "$method not available with DBD::Gofer") }
    }

    # for quote we rely on the default method + type_info_all
    # for quote_identifier we rely on the default method + get_info

    sub do {
        my $dbh = shift;
        delete $dbh->{Statement}; # avoid "Modification of non-creatable hash value attempted"
        $dbh->{Statement} = $_[0]; # for profiling and ShowErrorStatement
        return $dbh->go_dbh_method('do', undef, @_);
    }

    sub ping {
        my $dbh = shift;
        return $dbh->set_err(0, "can't ping while not connected") # warning
            unless $dbh->SUPER::FETCH('Active');
        # XXX local or remote - add policy attribute
        return $dbh->go_dbh_method('ping', undef, @_);
    }

    sub last_insert_id {
        my $dbh = shift;
        my $response = $dbh->{go_response} or return undef;
        # will be undef unless last_insert_id was explicitly requested
        return $response->last_insert_id;
    }

    sub FETCH {
	my ($dbh, $attrib) = @_;

        # forward driver-private attributes
        if ($attrib =~ m/^[a-z]/) { # XXX policy? precache on connect?
            my $value = $dbh->go_dbh_method('FETCH', undef, $attrib);
            $dbh->{$attrib} = $value;
            return $value;
        }

	# else pass up to DBI to handle
	return $dbh->SUPER::FETCH($attrib);
    }

    sub STORE {
	my ($dbh, $attrib, $value) = @_;
        if ($attrib eq 'AutoCommit') {
            return $dbh->SUPER::STORE($attrib => -901) if $value;
            croak "Can't enable transactions when using DBD::Gofer";
        }
	return $dbh->SUPER::STORE($attrib => $value)
            # we handle this attribute locally
            if $dbh_local_store_attrib{$attrib}
            # not yet connected (and being called by connect())
            or not $dbh->FETCH('Active');

	return $dbh->SUPER::STORE($attrib => $value)
            if $DBD::Gofer::xxh_local_store_if_same_attrib{$attrib}
            && do { local $^W; $value eq $dbh->FETCH($attrib) }; # XXX undefs

        # dbh attributes are set at connect-time - see connect()
        Carp::carp("Can't alter \$dbh->{$attrib}") if $dbh->FETCH('Warn');
        return $dbh->set_err(1, "Can't alter \$dbh->{$attrib}");
    }

    sub disconnect {
	my $dbh = shift;
        $dbh->{go_trans} = undef;
	$dbh->STORE(Active => 0);
    }

    # XXX + prepare_cached ?
    #
    sub prepare {
	my ($dbh, $statement, $attr)= @_;

        return $dbh->set_err(1, "Can't prepare when disconnected")
            unless $dbh->FETCH('Active');

        my $policy = $attr->{go_policy} || $dbh->{go_policy};

	my ($sth, $sth_inner) = DBI::_new_sth($dbh, {
	    Statement => $statement,
            go_prepare_call => [ 'prepare', [ $statement, $attr ] ],
            go_method_calls => [],
            go_request => $dbh->{go_request},
            go_trans => $dbh->{go_trans},
            go_policy => $policy,
        });

        #my $p_sep = $policy->skip_early_prepare($attr, $dbh, $statement, $attr, $sth);
        my $p_sep = 0;

        $p_sep = 1 if not defined $statement; # XXX hack, see go_dbh_method
        if (not $p_sep) {
            $sth->go_sth_method() or return undef;
        }

	return $sth;
    }

}


{   package DBD::Gofer::st; # ====== STATEMENT ======
    $imp_data_size = 0;
    use strict;

    my %sth_local_store_attrib = (%DBD::Gofer::xxh_local_store_attrib, NUM_OF_FIELDS => 1);

    sub go_sth_method {
        my ($sth) = @_;

        if (my $ParamValues = $sth->{ParamValues}) {
            my $ParamAttr = $sth->{ParamAttr};
            while ( my ($p, $v) = each %$ParamValues) {
                # unshift to put binds before execute call
                unshift @{ $sth->{go_method_calls} },
                    [ 'bind_param', $p, $v, $ParamAttr->{$p} ];
            }
        }

        my $request = $sth->{go_request};
        $request->init_request(@{$sth->{go_prepare_call}}, undef);
        $request->sth_method_calls($sth->{go_method_calls});
        $request->sth_result_attr({});

        my $transport = $sth->{go_trans}
            or return $sth->set_err(1, "Not connected (no transport)");
        eval { $transport->transmit_request($request) }
            or return $sth->set_err(1, "transmit_request failed: $@");
        my $response = $transport->receive_response;
        $sth->{go_response} = $response;
        delete $sth->{go_method_calls};

        if ($response->sth_resultsets) {
            # setup first resultset - including atributes
            $sth->more_results;
        }
        else {
            $sth->{go_rows} = $response->rv;
        }
        # set error/warn/info (after more_results as that'll clear err)
        DBD::Gofer::set_err_from_response($sth, $response);

        return $response->rv;
    }

    # sth methods that should always fail, at least for now
    for my $method (qw(
        bind_param_inout bind_param_array bind_param_inout_array execute_array execute_for_fetch
    )) {
        no strict 'refs';
        *$method = sub { return shift->set_err(1, "$method not available with DBD::Gofer, yet (patches welcome)") }
    }


    sub bind_param {
        my ($sth, $param, $value, $attr) = @_;
        $sth->{ParamValues}{$param} = $value;
        $sth->{ParamAttr}{$param} = $attr;
        return 1;
    }


    sub execute {
	my $sth = shift;
        $sth->bind_param($_, $_[$_-1]) for (1..@_);
        push @{ $sth->{go_method_calls} }, [ 'execute' ];
        return $sth->go_sth_method;
    }


    sub more_results {
	my ($sth) = @_;

	$sth->finish if $sth->FETCH('Active');

	my $resultset_list = $sth->{go_response}->sth_resultsets
            or return $sth->set_err(1, "No sth_resultsets");

        my $meta = shift @$resultset_list
            or return undef; # no more result sets

        # pull out the special non-atributes first
        my ($rowset, $err, $errstr, $state)
            = delete @{$meta}{qw(rowset err errstr state)};

        # copy meta attributes into attribute cache
        my $NUM_OF_FIELDS = delete $meta->{NUM_OF_FIELDS};
        $sth->STORE('NUM_OF_FIELDS', $NUM_OF_FIELDS);
        $sth->{$_} = $meta->{$_} for keys %$meta;

        if (($NUM_OF_FIELDS||0) > 0) {
            $sth->{go_rows}           = ($rowset) ? @$rowset : -1;
            $sth->{go_current_rowset} = $rowset;
            $sth->{go_current_rowset_err} = [ $err, $errstr, $state ]
                if defined $err;
            $sth->STORE(Active => 1) if $rowset;
        }

	return $sth;
    }


    sub fetchrow_arrayref {
	my ($sth) = @_;
	my $resultset = $sth->{go_current_rowset}
            or return $sth->set_err( @{ $sth->{go_current_rowset_err} } );
        return $sth->_set_fbav(shift @$resultset) if @$resultset;
	$sth->finish;     # no more data so finish
	return undef;
    }
    *fetch = \&fetchrow_arrayref; # alias


    sub fetchall_arrayref {
        my ($sth, $slice, $max_rows) = @_;
        my $mode = ref($slice) || 'ARRAY';
        return $sth->SUPER::fetchall_arrayref($slice, $max_rows)
            if ref($slice) or defined $max_rows;
	my $resultset = $sth->{go_current_rowset}
            or return $sth->set_err( @{ $sth->{go_current_rowset_err} } );
	$sth->finish;     # no more data so finish
        return $resultset;
    }


    sub rows {
        return shift->{go_rows};
    }


    sub STORE {
	my ($sth, $attrib, $value) = @_;
	return $sth->SUPER::STORE($attrib => $value)
            if $sth_local_store_attrib{$attrib}  # handle locally
            or $attrib =~ m/^[a-z]/;             # driver-private XXX

        # could perhaps do
        #   push @{ $sth->{go_method_calls} }, [ 'STORE', $attrib, $value ];
        # if not $sth->FETCH('Executed')
        # but how to handle repeat executions? How to we know when an
        # attribute is being set to affect the current resultset or the
        # next execution? Could just always use go_method_calls I guess.
        Carp::carp("Can't alter \$sth->{$attrib}") if $sth->FETCH('Warn');
        return $sth->set_err(1, "Can't alter \$sth->{$attrib}");
    }

}

1;

__END__

=head1 NAME

DBD::Gofer - A stateless-proxy driver for communicating with a remote DBI

=head1 SYNOPSIS

  use DBI;

  $original_dsn = "dbi:..."; # your original DBI Data Source Name

  $dbh = DBI->connect("dbi:Gofer:transport=$transport;...;dsn=$original_dsn",
                      $user, $passwd, \%attributes);

  ... use $dbh as if it was connected to $original_dsn ...


The C<transport=$transport> part specifies the name of the module to use to
transport the requests to the remote DBI. If $transport doesn't contain any
double colons then it's prefixed with C<DBD::Gofer::Transport::>.

The C<dsn=$original_dsn> part I<must be the last element> of the DSN because
everything after C<dsn=> is assumed to be the DSN that the remote DBI should
use.

The C<...> represents attributes that influence the operation of the Gofer
driver or transport. These are described below or in the documentation of the
transport module being used.

=head1 DESCRIPTION

DBD::Gofer is a DBI database driver that forwards requests to another DBI
driver, usually in a seperate process, often on a separate machine. It tries to
be as transparent as possible so it appears that you are using the remote
driver directly.

DBD::Gofer is very similar to DBD::Proxy. The major difference is that with
DBD::Gofer no state is maintained on the remote end. That means every
request contains all the information needed to create the required state. (So,
for example, every request includes the DSN to connect to.) Each request can be
sent to any available server. The server executes the request and returns a
single response that includes all the data.

This is very similar to the way http works as a stateless protocol for the web.
Each request from your web browser can be handled by a different web server process.

This may seem like pointless overhead but there are situations where this is a
very good thing. Let's consider a specific case.

Imagine using DBD::Gofer with an http transport. Your application calls
connect(), prepare("select * from table where foo=?"), bind_param(), and execute().
At this point DBD::Gofer builds a request containing all the information
about the method calls. It then uses the httpd transport to send that request
to an apache web server.

This 'dbi execute' web server executes the request (using DBI::Gofer::Execute
and related modules) and builds a response that contains all the rows of data,
if the statement returned any, along with all the attributes that describe the
results, such as $sth->{NAME}. This response is sent back to DBD::Gofer which
unpacks it and presents it to the application as if it had executed the
statement itself.

Okay, but you still don't see the point? Well let's consider what we've gained:

=head3 Connection Pooling and Throttling

The 'dbi execute' web server leverages all the functionality of web
infrastructure in terms of load balancing, high-availability, firewalls, access
management, proxying, caching.

At it's most basic level you get a configurable pool of persistent database connections.

=head3 Simple Scaling

Got thousands of processes all trying to connect to the database? You can use
DBD::Gofer to connect them to your pool of 'dbi execute' web servers instead.

=head3 Caching

Not yet implemented, but the single request-response architecture lends itself to caching.

=head3 Fewer Network Round-trips

DBD::Gofer sends as few requests as possible.

=head3 Thin Clients / Unsupported Platforms

You no longer need drivers for your database on every system.  DBD::Gofer is pure perl.

=head1 CONSTRAINTS

There are naturally a some constraints imposed by DBD::Gofer. But not many:

=head2 You can't change database handle attributes

You can't change database handle attributes after you've connected.
Use the connect() call to specify all the attribute settings you want.

This is because it's critical that when a request is complete the database
handle is left in the same state it was when first connected.

=head2 You can't use transactions.

AutoCommit only. Transactions aren't supported.

=head2 You need to use func() to call driver-private dbh methods

So instead of the new-style:

    $dbh->foo_method_name(...)

you need to use the old-style:

    $dbh->func(..., 'foo_method_name');

This constraint might be removed in future.

=head2 You can't call driver-private sth methods

But few people need to do that.

=head2 Array Methods are not supported

The array methods (bind_param_inout bind_param_array bind_param_inout_array execute_array execute_for_fetch)
are not currently supported. Patches welcome, of course.

=head1 CAVEATS

A few things to keep in mind when using DBD::Gofer:

=head2 Driver-private Database Handle Attributes

Some driver-private dbh attributes may not be available, currently.
In future it will be possible to indicate which attributes you'd like to be
able to read.

=head2 Driver-private Statement Handle Attributes

Driver-private sth attributes can be set in the prepare() call. TODO

Some driver-private sth attributes may not be available, currently.
In future it will be possible to indicate which attributes you'd like to be
able to read.

=head1 Multiple Resultsets

Multiple resultsets are supported if the driver supports the more_results() method.

=head1 TRANSPORTS

DBD::Gofer doesn't concern itself with transporting requests and responses to and fro.
For that it uses special Gofer transport modules.

Gofer transport modules usually come in pairs: one for the 'client' DBD::Gofer
driver to use and one for the remote 'server' end. They have very similar names:

    DBD::Gofer::Transport::<foo>
    DBI::Gofer::Transport::<foo>

Several transport modules are provided with DBD::Gofer:

=head2 null

The null transport is the simplest of them all. It doesn't actually transport the request anywhere.
It just serializes (freezes) the request into a string, then thaws it back into
a data structure before passing it to DBI::Gofer::Execute to execute. The same
freeze and thaw is applied to the results.

The null transport is the best way to test if your application will work with Gofer.
Just set the DBI_AUTOPROXY environment variable to "C<dbi:Gofer:transport=null>"
(see L</DBI_AUTOPROXY> below) and run your application, or ideally its test suite, as usual.

It doesn't take any parameters.

=head2 pipeone

The pipeone transport launches a subprocess for each request. It passes in the
request and reads the response. The fact that a new subprocess is started for
each request proves that the server side is truely stateless. It also makes
this transport very slow. It's useful, however, both as a proof of concept and
as a base class for the stream driver.

It doesn't take any parameters.

=head2 stream

The stream driver also launches a subprocess and writes requests and reads
responses, like the pipeone transport.  In this case, however, the subprocess
is expected to handle more that one request. (Though it will be restarted if it exits.)

This is the first transport that is truly useful because it can launch the
subprocess on a remote machine using ssh. This means you can now use DBD::Gofer
to easily access any databases that's accessible from any system you can login to.
You also get all the benefits of ssh, including encryption and optional compression.

See L</DBI_AUTOPROXY> below for an example.

=head2 http

The http driver uses the http protocol to send Gofer requests and receive replies.

XXX not yet implemented

=head1 CONNECTING

Simply prefix your existing DSN with "C<dbi:Gofer:transport=$transport;dsn=>"
where $transport is the name of the Gofer transport you want to use (see L</TRANSPORTS>).
The C<transport> and C<dsn> attributes must be specified and the C<dsn> attributes must be last.

Other attributes can be specified in the DSN to configure DBD::Gofer and/or the transport being used.

XXX

=head2 Using DBI_AUTOPROXY

The simplest way to try out DBD::Gofer is to set the DBI_AUTOPROXY environment variable.
In this case you don't include the C<dsn=> part.

    export DBI_AUTOPROXY=dbi:Gofer:transport=null

or

    export DBI_AUTOPROXY=dbi:Gofer:transport=stream;url=ssh:user@example.com


=head1 CONFIGURING VIA POLICY

XXX

=head1 AUTHOR AND COPYRIGHT

The DBD::Gofer, DBD::Gofer::* and DBI::Gofer::* modules are
Copyright (c) 2007 Tim Bunce. Ireland.  All rights reserved.

You may distribute under the terms of either the GNU General Public License or
the Artistic License, as specified in the Perl README file.

=head1 SEE ALSO

L<DBD::Gofer::Request>, L<DBD::Gofer::Response>, L<DBD::Gofer::Transport::Base>,

L<DBI>, L<DBI::Gofer::Execute>.


=head1 TODO

Random brain dump...

Add policy mechanism

Add mecahism for transports to list config params
and for Gofer to apply any that match
(and warn if any left over?)

Test existing compiled drivers (ie DBD::mysql) for binary compatibility

Driver-private sth attributes - set via prepare() - change DBI spec

Caching of get_info values

prepare vs prepare_cached

Driver-private sth methods via func? Can't be sure of state?

track installed_methods and install proxies on client side after connect?

add hooks into transport base class for checking & updating a cache
   ie via a standard cache interface such as:
   http://search.cpan.org/~robm/Cache-FastMmap/FastMmap.pm
   http://search.cpan.org/~bradfitz/Cache-Memcached/lib/Cache/Memcached.pm
   http://search.cpan.org/~dclinton/Cache-Cache/
   http://search.cpan.org/~cleishman/Cache/
Also caching instructions could be passed through the httpd transport layer
in such a way that appropriate http cache headers are added to the results
so that web caches (squid etc) could be used to implement the caching.
(May require the use of GET rather than POST requests.)

=cut
