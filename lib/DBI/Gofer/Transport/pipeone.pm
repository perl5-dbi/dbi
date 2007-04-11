package DBI::Gofer::Transport::pipeone;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;
use warnings;

use DBI::Gofer::Execute;

use base qw(DBI::Gofer::Transport::Base Exporter);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

our @EXPORT = qw(run_one_stdio);

my $executor = DBI::Gofer::Execute->new();

sub run_one_stdio {

    my $transport = DBI::Gofer::Transport::pipeone->new();

    my $frozen_request = do { local $/; <STDIN> };

    my $response = $executor->execute_request( $transport->thaw_request($frozen_request) );

    my $frozen_response = $transport->freeze_response($response);

    print $frozen_response;
}

1;
__END__

=head1 NAME
    
DBI::Gofer::Transport::pipeone - DBD::Gofer server-side transport for pipeone
    
=head1 SYNOPSIS

See L<DBD::Gofer::Transport::pipeone>.

=head1 AUTHOR AND COPYRIGHT

The DBD::Gofer, DBD::Gofer::* and DBI::Gofer::* modules are
Copyright (c) 2007 Tim Bunce. Ireland.  All rights reserved.

You may distribute under the terms of either the GNU General Public License or
the Artistic License, as specified in the Perl README file.


=cut

