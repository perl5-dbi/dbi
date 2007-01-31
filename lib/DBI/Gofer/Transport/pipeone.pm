package DBI::Gofer::Transport::pipeone;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;
use warnings;

use DBI::Gofer::Execute qw(execute_request);

use base qw(DBI::Gofer::Transport::Base Exporter);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

our @EXPORT = qw(run_one_stdio);


sub run_one_stdio {

    my $self = DBI::Gofer::Transport::pipeone->new();

    my $frozen_request = do { local $/; <STDIN> };

    my $response = execute_request( $self->thaw_data($frozen_request) );

    my $frozen_response = $self->freeze_data($response);

    print $frozen_response;
}


1;
