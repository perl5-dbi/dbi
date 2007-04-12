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

    my $transport = DBI::Gofer::Transport::stream->new();
    local $| = 1;

    DBI->trace_msg("$0 started (pid $$)\n");

    local $\; # OUTPUT_RECORD_SEPARATOR
    local $/ = "\012"; # INPUT_RECORD_SEPARATOR
    while ( defined( my $encoded_request = <STDIN> ) ) {
        $encoded_request =~ s/\015?\012$//;

        my $request = $transport->thaw_request( pack "H*", $encoded_request );
        my $response = $executor->execute_request( $request );

        my $encoded_response = unpack "H*", $transport->freeze_response($response);

        print $encoded_response, "\015\012"; # autoflushed due to $|=1
    }
    DBI->trace_msg("$0 ending (pid $$)\n");
}

1;
__END__

=head1 NAME
    
DBI::Gofer::Transport::stream - DBD::Gofer server-side transport for stream
    
=head1 SYNOPSIS

See L<DBD::Gofer::Transport::stream>.

=head1 AUTHOR AND COPYRIGHT

The DBD::Gofer, DBD::Gofer::* and DBI::Gofer::* modules are
Copyright (c) 2007 Tim Bunce. Ireland.  All rights reserved.

You may distribute under the terms of either the GNU General Public License or
the Artistic License, as specified in the Perl README file.


=cut

