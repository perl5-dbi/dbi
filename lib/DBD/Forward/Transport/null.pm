package DBD::Forward::Transport::null;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;
use warnings;

use base qw(DBD::Forward::Transport::Base);

use DBI::Forward::Execute qw(execute_request);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

__PACKAGE__->mk_accessors(qw(
    fwd_pending_response
)); 


sub transmit_request {
    my ($self, $request) = @_;

    my $frozen_request = $self->freeze_data($request);

    # ...
    # the request is magically transported over to ... ourselves
    # ...

    my $response = execute_request( $self->thaw_data($frozen_request) );

    # put response 'on the shelf' ready for receive_response()
    $self->fwd_pending_response( $response );

    return 1;
}


sub receive_response {
    my $self = shift;

    my $response = $self->fwd_pending_response;

    my $frozen_response = $self->freeze_data($response);

    # ...
    # the response is magically transported back to ... ourselves
    # ...

    return $self->thaw_data($frozen_response);
}


1;
