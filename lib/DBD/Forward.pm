{
    package DBD::Forward;

    use strict;

    require DBI;
    require DBI::Forward::Request;
    require DBI::Forward::Response;
    require Carp;

    our $VERSION = sprintf("%d.%02d", q$Revision: 11.4 $ =~ /(\d+)\.(\d+)/o);

#   $Id: Forward.pm 2488 2006-02-07 22:24:43Z timbo $
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

    # attributes we'll allow local STORE
    our %xxh_local_store_attrib = map { $_=>1 } qw(
        Active
        CachedKids
        ErrCount Executed
        FetchHashKeyName
        HandleError HandleSetErr
        InactiveDestroy
        PrintError PrintWarn
        Profile
        RaiseError
        ShowErrorStatement
        Taint TaintIn TaintOut
        TraceLevel
        Warn
    );

    our $drh = undef;	# holds driver handle once initialised

    sub driver{
	return $drh if $drh;

        DBI->setup_driver('DBD::Forward');

        DBD::Forward::db->install_method('fwd_dbh_method', { O=> 0x0004 }); # IMA_KEEP_ERR

	my($class, $attr) = @_;
	$class .= "::dr";
	($drh) = DBI::_new_drh($class, {
	    'Name' => 'Forward',
	    'Version' => $VERSION,
	    'Attribution' => 'DBD Forward by Tim Bunce',
        });

	$drh;
    }

    sub CLONE {
        undef $drh;
    }

}


{   package DBD::Forward::dr; # ====== DRIVER ======

    my %dsn_attr_defaults = (
        fwd_dsn => undef,
        fwd_url => undef,
        fwd_transport => undef,
    );

    $imp_data_size = 0;
    use strict;

    sub connect {
        my($drh, $dsn, $user, $auth, $attr)= @_;
        my $orig_dsn = $dsn;

        # first remove dsn= and everything after it
        my $fwd_dsn = ($dsn =~ s/\bdsn=(.*)$// && $1)
            or return $drh->set_err(1, "No dsn= argument in '$orig_dsn'");

        my %dsn_attr = (%dsn_attr_defaults, fwd_dsn => $fwd_dsn);
        # extract fwd_ attributes
        for my $k (grep { /^fwd_/ } keys %$attr) {
            $dsn_attr{$k} = delete $attr->{$k};
        }
        # then override with attributes embedded in dsn
        for my $kv (grep /=/, split /;/, $dsn, -1) {
            my ($k, $v) = split /=/, $kv, 2;
            $dsn_attr{ "fwd_$k" } = $v;
        }
        if (keys %dsn_attr > keys %dsn_attr_defaults) {
            delete @dsn_attr{ keys %dsn_attr_defaults };
            return $drh->set_err(1, "Unknown attributes: @{[ keys %dsn_attr ]}");
        }

        my $transport_class = $dsn_attr{fwd_transport}
            or return $drh->set_err(1, "No transport= argument in '$orig_dsn'");
        $transport_class = "DBI::Forward::Transport::$dsn_attr{fwd_transport}"
            unless $transport_class =~ /::/;
        eval "require $transport_class"
            or return $drh->set_err(1, "Error loading $transport_class: $@");
        my $fwd_trans = eval { $transport_class->new(\%dsn_attr) }
            or return $drh->set_err(1, "Error instanciating $transport_class: $@");

        # XXX user/pass of fwd server vs db server
        my $request_class = "DBI::Forward::Request";
        my $fwd_request = eval {
            $request_class->new({
                connect_args => [ $fwd_dsn, $user, $auth, $attr ]
            })
        } or return $drh->set_err(1, "Error instanciating $request_class $@");

        my ($dbh, $dbh_inner) = DBI::_new_dbh($drh, {
            'Name' => $dsn,
            'USER' => $user,
            fwd_trans => $fwd_trans,
            fwd_request => $fwd_request,
        });

        # store and delete the attributes before marking connection Active
        $dbh->STORE($_ => delete $attr->{$_}) for keys %$attr;

        $dbh->STORE(Active => 1);

        return $dbh;
    }

    sub DESTROY { undef }
}


{   package DBD::Forward::db; # ====== DATABASE ======
    $imp_data_size = 0;
    use strict;
    use Carp qw(croak);

    my %dbh_local_store_attrib = %DBD::Forward::xxh_local_store_attrib;

    sub fwd_dbh_method {
        my ($dbh, $method, $meta, @args) = @_;
        $dbh->trace_msg("     fwd_dbh_method($dbh, $method, @args)\n");
        my $request = $dbh->{fwd_request};
        $request->init_request($method, \@args, wantarray);

        my $response = $dbh->{fwd_trans}->execute($request);

        $dbh->{fwd_response} = $response;

        $dbh->set_err($response->err, $response->errstr, $response->state);
        #$dbh->rows($response->rows); # can't, and not needed?
        my $rv = $response->rv;
        return (wantarray) ? @$rv : $rv->[0];
    }

    # Methods that should be forwarded
    # XXX ping? local or remote - add policy attribute
    # XXX get_info? special sub to lazy-cache individual values
    for my $method (qw(
        do data_sources
        table_info column_info primary_key_info foreign_key_info statistics_info
        type_info_all get_info
        ping
    )) {
        no strict 'refs';
        *$method = sub { return shift->fwd_dbh_method($method, undef, @_) }
    }

    # Methods that should always fail
    for my $method (qw(
        begin_work commit rollback
    )) {
        no strict 'refs';
        *$method = sub { return shift->set_err(1, "$method not available") }
    }

    # for quote we rely on the default method + type_info_all
    # for quote_identifier we rely on the default method + get_info

    sub last_insert_id {
        my $dbh = shift;
        my $response = $dbh->{fwd_response} or return undef;
        # will be undef unless last_insert_id was explicitly requested
        return $response->last_insert_id;
    }

    sub FETCH {
	my ($dbh, $attrib) = @_;
	# AutoCommit needs special handling
	return 1 if $attrib eq 'AutoCommit';
	# else pass up to DBI to handle
	return $dbh->SUPER::FETCH($attrib);
    }

    sub STORE {
	my ($dbh, $attrib, $value) = @_;
        if ($attrib eq 'AutoCommit') {
            return 1 if $value;
            croak "Can't enable transactions when using DBD::Forward";
        }
	return $dbh->SUPER::STORE($attrib => $value)
            if $dbh_local_store_attrib{$attrib}  # handle locally
            or $attrib =~ m/^[a-z]/              # driver-private
            or not $dbh->FETCH('Active');        # not yet connected

        # ignore values that aren't actually being changed
        my $prev = $dbh->FETCH($attrib);
        return 1 if !defined $value && !defined $prev
                 or defined $value && defined $prev && $value eq $prev;

        # dbh attributes are set at connect-time - see connect()
        Carp::carp("Can't alter \$dbh->{$attrib}");
        return $dbh->set_err(1, "Can't alter \$dbh->{$attrib}");
    }

    sub disconnect {
        # XXX discard state for dbh and destroy child handles
	shift->STORE(Active => 0);
    }

    sub prepare {
	my ($dbh, $statement, $attr)= @_;

        return $dbh->set_err(1, "Can't prepare when disconnected")
            unless $dbh->FETCH('Active');

	my ($outer, $sth) = DBI::_new_sth($dbh, {
	    Statement => $statement,
            fwd_prepare_args => [ $statement, $attr ],
            fwd_method_calls => [],
            fwd_request => $dbh->{fwd_request},
            fwd_trans => $dbh->{fwd_trans},
        });

	$outer;
    }

}


{   package DBD::Forward::st; # ====== STATEMENT ======
    $imp_data_size = 0;
    use strict;

    sub execute {
	my($sth, @bind) = @_;

        # XXX validate that @bind==NUM_OFPARAM
        $sth->bind_param($_, $bind[$_-1]) for (1..@bind);

        my $request = $sth->{fwd_request};
        $request->init_request('prepare', $sth->{fwd_prepare_args}, undef);
        $request->sth_method_calls($sth->{fwd_method_calls});
        $request->sth_result_attr({});

        my $response = $sth->{fwd_trans}->execute($request);

        $sth->{fwd_response} = $response;
        $sth->{fwd_method_calls} = [];

        # setup first resultset
        $sth->more_results if $response->sth_resultsets;

        $sth->set_err($response->err, $response->errstr, $response->state);
        return $response->rv;
    }


    # Methods that should always fail, at least for now
    for my $method (qw(
        bind_param_inout bind_param_array bind_param_inout_array execute_array execute_for_fetch
    )) {
        no strict 'refs';
        *$method = sub { return shift->set_err(1, "$method not available") }
    }


    sub bind_param {
        my ($sth, $param, $value, $attr) = @_;
        $sth->{ParamValues}{$param} = $value;
        push @{ $sth->{fwd_method_calls} }, [ 'bind_param', $param, $value, $attr ];
        return 1;
    }

    sub fetchrow_arrayref {
	my ($sth) = @_;
	my $resultset = $sth->{fwd_current_resultset}
            or return $sth->set_err(1, "No result set available");
        return shift @$resultset if @$resultset;
	$sth->finish;     # no more data so finish
	return undef;
    }
    *fetch = \&fetchrow_arrayref; # alias

    sub more_results {
	my ($sth) = @_;
	$sth->finish if $sth->FETCH('Active');
	my $resultset_list = $sth->{fwd_response}->sth_resultsets
            or return $sth->set_err(1, "No sth_resultsets");
        return undef unless @$resultset_list;
        my $meta = shift @$resultset_list
            or return undef; # no more result sets
        $sth->{fwd_current_resultset} = delete $meta->{rowset}
            or return $sth->set_err(1, "No rowset in meta");
        # copy meta attributes into attribute cache
        $sth->{$_} = $meta->{$_} for keys %$meta;
	return $sth;
    }

    sub rows {
        my $sth = shift;
        my $response = $sth->{fwd_response} or return -1;
        return $response->rv;
    }

    sub STORE {
	my ($sth, $attrib, $value) = @_;
        DBD::Forward::_note_attrib_store($sth, $attrib, $value);
	return $sth->SUPER::STORE($attrib, $value);
    }

}

1;
