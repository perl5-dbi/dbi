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


sub new_response {
    my $self = shift;
    return DBI::Gofer::Response->new(@_);
}


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
            return self->new_response({ err => 1, errstr => $@ });
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
            return $self->new_response({ err => 1, errstr => $@ });
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
        $retry = 1 if $errstr =~ m/fake error induced by DBI_GOFER_RANDOM/;
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
    return $self->new_response({ err => 1, errstr => "DBD::Gofer $method timed-out after $timeout seconds" });
}


1;

=head1 NAME

DBD::Gofer::Transport::Base - base class for DBD::Gofer client transports

=head1 SYNOPSIS

  my $remote_dsn = "..."
  DBI->connect("dbi:Gofer:transport=...;url=...;timeout=...;retry_limit=...;dsn=$remote_dsn",...)
            
or, enable by setting the DBI_AUTOPROXY environment variable:
                
  export DBI_AUTOPROXY='dbi:Gofer:transport=...;url=...'
        
which will force I<all> DBI connections to be made via that Gofer server.

=head1 DESCRIPTION

This is the base class for all DBD::Gofer client transports.

=head1 ATTRIBUTES

Gofer transport attributes can be specified either in the attributes parameter
of the connect() method call, or in the DSN string. When used in the DSN
string, attribute names don't have the C<go_> prefix.

=head2 go_dsn

The full DBI DSN that the Gofer server should connect to on your behalf.

When used in the DSN it must be the last element in the DSN string.

=head2 go_timeout

A time limit for sending a request and receiving a response. Some drivers may
implement sending and receiving as separate steps, in which case (currently)
the timeout applies to each separately.

If a request needs to be resent then the timeout is restarted for each sending
of a request and receiving of a response.

=head2 go_retry_limit

The maximum number of times an request may be retried. The default is 2.

=head2 go_retry_hook

This subroutine reference is called, if defined, for each response received where $response->err is true.

The subroutine is pass three parameters: the request object, the response object, and the transport object.

If it returns an undefined value then the default retry behaviour is used. See L</RETRY ON ERROR> below.

If it returns a defined but false value then the request is not resent.

If it returns true value then the request is resent, so long as the number of retries does not exceed C<go_retry_limit>.

=head1 RETRY ON ERROR

The default retry on error behaviour is:

 - Retry if the error was due to DBI_GOFER_RANDOM. See L<DBI::Gofer::Execute>.

 - Retry if $request->is_idempotent returns true. See L<DBI::Gofer::Request>.

A retry won't be allowed if the number of previous retries has reached C<go_retry_limit>.

=head1 TRACING

Tracing of gofer requests and reponses can be enabled by setting the
C<DBD_GOFER_TRACE> environment variable. A value of 1 gives a reasonably
compact summary o each request and response. A value of 2 or more gives a
detailed, and voluminous, dump.

The trace is written using DBI->trace_msg() and so is written to the default
DBI trace output, which is usually STDERR.

=head1 AUTHOR AND COPYRIGHT

The DBD::Gofer, DBD::Gofer::* and DBI::Gofer::* modules are
Copyright (c) 2007 Tim Bunce. Ireland.  All rights reserved.

You may distribute under the terms of either the GNU General Public License or
the Artistic License, as specified in the Perl README file.

=head1 SEE ALSO

L<DBD::Gofer>, L<DBI::Gofer::Request>, L<DBI::Gofer::Response>, L<DBI::Gofer::Execute>.

and some example transports:

L<DBD::Gofer::Transport::stream>

L<DBD::Gofer::Transport::http>

L<DBI::Gofer::Transport::mod_perl>

=cut
