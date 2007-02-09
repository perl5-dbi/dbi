package DBI::Gofer::Transport::stream;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;
use warnings;

use DBI::Gofer::Execute;

use base qw(DBI::Gofer::Transport::pipeone Exporter);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

our @EXPORT = qw(run_stdio_hex);

my $executor = DBI::Gofer::Execute->new();

sub run_stdio_hex {

    my $self = DBI::Gofer::Transport::stream->new();
    local $| = 1;

    #warn "STARTED $$";

    while ( my $frozen_request = <STDIN> ) {

        my $request = $self->thaw_data( pack "H*", $frozen_request );
        my $response = $executor->execute_request( $request );

        my $frozen_response = unpack "H*", $self->freeze_data($response);

        print $frozen_response, "\n"; # autoflushed due to $|=1
    }
}


1;
