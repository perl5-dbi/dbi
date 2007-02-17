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

use DBI::Gofer::Execute;

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

__PACKAGE__->mk_accessors(qw(
    pending_response
)); 

my $executor = DBI::Gofer::Execute->new();


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
    #my $prev_trace_level = DBI->trace( ($ENV{DBD_GOFER_NULL_TRACE}) ? (split /=/, $ENV{DBD_GOFER_NULL_TRACE}) : (0));

    my $response = $executor->execute_request( $self->thaw_data($frozen_request,1) );

    #DBI->trace($prev_trace_level);

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
__END__

=head1 NAME
    
DBD::Gofer::Transport::null - DBD::Gofer client transport for testing

=head1 SYNOPSIS

  my $original_dsn = "..."
  DBI->connect("dbi:Gofer:transport=null;dsn=$original_dsn",...)

or, enable by setting the DBI_AUTOPROXY environment variable:

  export DBI_AUTOPROXY="dbi:Gofer:transport=null"

=head1 DESCRIPTION

Connect via DBD::Gofer but execute the requests within the same process.

This is a quick and simple way to test applications for compatibility with the
(few) restrictions that DBD::Gofer imposes.

It also provides a simple, portable way for the DBI test suite to be used to
test DBD::Gofer on all platforms with no setup.

Also, by measuring the difference in performance between normal connections and
connections via C<dbi:Gofer:transport=null> the basic cost of using DBD::Gofer
can be measured. Furthermore, the additional cost of more advanced transports can be 
isolated by comparing their performance with the null transport.

The C<t/85gofer.t> script in the DBI distribution includes a comparative benchmark.

=head1 SEE ALSO

L<DBD::Gofer>

=cut
