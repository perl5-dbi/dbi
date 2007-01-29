package DBD::Gofer::Transport::null;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;
use warnings;

use base qw(DBD::Gofer::Transport::Base);

use DBI::Gofer::Execute qw(execute_request);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

__PACKAGE__->mk_accessors(qw(
    pending_response
)); 


sub transmit_request {
    my ($self, $request) = @_;

    my $frozen_request = $self->freeze_data($request);

    # ...
    # the request is magically transported over to ... ourselves
    # ...

    # since we're in the same process, we don't want to show the DBI trace
    # enabled for the 'client' because it gets very hard to follow.
    # So control the Gofer 'server' side independently
    # but similar logic as used for DBI_TRACE parsing.
    my $prev_trace_level = DBI->trace(
        ($ENV{DBD_GOFER_NULL_TRACE}) ? (split /=/, $ENV{DBD_GOFER_NULL_TRACE}) : (0)
    );

    my $response = execute_request( $self->thaw_data($frozen_request,1) );

    DBI->trace($prev_trace_level);

    # put response 'on the shelf' ready for receive_response()
    $self->pending_response( $response );

    return 1;
}


sub receive_response {
    my $self = shift;

    my $response = $self->pending_response;

    my $frozen_response = $self->freeze_data($response,1);

    # ...
    # the response is magically transported back to ... ourselves
    # ...

    return $self->thaw_data($frozen_response);
}


1;
