package DBD::Gofer::Transport::Base;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;
use warnings;

use base qw(DBI::Gofer::Transport::Base);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

__PACKAGE__->mk_accessors(qw(
    trace
    go_dsn
    go_url
    go_timeout
    go_retry_hook
    go_retry_limit
));
__PACKAGE__->mk_accessors_using(make_accessor_autoviv_hashref => qw(
    meta
));



sub _init_trace { $ENV{DBD_GOFER_TRACE} || 0 }

sub transmit_request {
    my ($self, $request) = @_;
    my $to = $self->go_timeout;

    my $transmit_sub = sub {
        $self->trace_msg("transmit_request\n");
        local $SIG{ALRM} = sub { die "TIMEOUT\n" } if $to;

        my $response = eval {
            local $SIG{PIPE} = sub {
                my $extra = ($! eq "Broken pipe") ? "" : " ($!)";
                die "Unable to send request: Broken pipe$extra\n";
            };
            alarm($to) if $to;
            $self->transmit_request_by_transport($request);
        };
        alarm(0) if $to;

        if ($@) {
            return $self->transport_timedout("transmit_request", $to)
                if $@ eq "TIMEOUT\n";
            return DBI::Gofer::Response->new({ err => 1, errstr => $@ });
        }

        return $response;
    };

    my $response = $self->_transmit_request_with_retries($request, $transmit_sub);

    $self->trace_msg("transmit_request is returing a response itself\n") if $response;

    return $response unless wantarray;
    return ($response, $transmit_sub);
}


sub _transmit_request_with_retries {
    my ($self, $request, $transmit_sub) = @_;
    my $response;
    do {
        $response = $transmit_sub->();
    } while ( $response && $self->response_needs_retransmit($request, $response) );
    return $response;
}


sub receive_response {
    my ($self, $request, $retransmit_sub) = @_;
    my $to = $self->go_timeout;

    my $receive_sub = sub {
        $self->trace_msg("receive_response\n");
        local $SIG{ALRM} = sub { die "TIMEOUT\n" } if $to;

        my $response = eval {
            alarm($to) if $to;
            $self->receive_response_by_transport();
        };
        alarm(0) if $to;

        if ($@) {
            return $self->transport_timedout("receive_response", $to)
                if $@ eq "TIMEOUT\n";
            return DBI::Gofer::Response->new({ err => 1, errstr => $@ });
        }
        return $response;
    };

    my $response;
    do {
        $response = $receive_sub->();
        if ($self->response_needs_retransmit($request, $response)) {
            $response = $self->_transmit_request_with_retries($request, $retransmit_sub);
            $response ||= $receive_sub->();
        }
    } while ( $self->response_needs_retransmit($request, $response) );

    return $response;
}


sub response_needs_retransmit {
    my ($self, $request, $response) = @_;

    my $err = $response->err
        or return 0; # nothing went wrong

    my $retry;

    # give the user a chance to express a preference (or undef for default)
    if (my $go_retry_hook = $self->go_retry_hook) {
        $retry = $go_retry_hook->($request, $response, $self);
        $self->trace_msg(sprintf "response_needs_retransmit: go_retry_hook returned %s\n",
            (defined $retry) ? $retry : 'undef');
    }

    if (not defined $retry) {
        my $errstr = $response->errstr || '';
        $retry = 1 if $errstr =~ m/fake error induced by DBI_GOFER_RANDOM_FAIL/;
    }

    if (not defined $retry) {
        my $idempotent = $request->is_idempotent; # i.e. is SELECT or ReadOnly was set
        $retry = 1 if $idempotent;
    }

    if (!$retry) {  # false or undef
        $self->trace_msg("response_needs_retransmit: response not suitable for retry\n");
        return 0;
    }

    my $meta = $request->meta;
    my $retry_limit = $self->go_retry_limit;
    $retry_limit = 2 unless defined $retry_limit;
    if (($meta->{retry_count}||=0) >= $retry_limit) {
        $self->trace_msg("response_needs_retransmit: $meta->{retry_count} is too many retries\n");
        return 0;
    }
    ++$meta->{retry_count};                 # count for this request
    ++$self->meta->{request_retry_count};   # cumulative transport stats
    $self->trace_msg("response_needs_retransmit: retry $meta->{retry_count}\n");
    return 1;
}


sub transport_timedout {
    my ($self, $method, $timeout) = @_;
    $timeout ||= $self->go_timeout;
    return DBI::Gofer::Response->new({ err => 1, errstr => "DBD::Gofer $method timed-out after $timeout seconds" });
}


1;

=head1 NAME

DBD::Gofer::Transport::Base - base class for DBD::Gofer client transports


=head1 AUTHOR AND COPYRIGHT

The DBD::Gofer, DBD::Gofer::* and DBI::Gofer::* modules are
Copyright (c) 2007 Tim Bunce. Ireland.  All rights reserved.

You may distribute under the terms of either the GNU General Public License or
the Artistic License, as specified in the Perl README file.

=head1 SEE ALSO

L<DBD::Gofer>

and some example transports:

L<DBD::Gofer::Transport::stream>

L<DBD::Gofer::Transport::http>

L<DBI::Gofer::Transport::mod_perl>

=cut
