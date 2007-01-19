package DBI::Forward::Transport::null;

use strict;
use warnings;

use Data::Dumper;

our $debug = 0;

use Storable qw(freeze thaw);

use DBI::Forward::Execute qw(execute_request);

use base qw(DBI::Forward::Transport::Base);

sub execute {
    my ($self, $request) = @_;
    warn "REQUEST=".Dumper($request) if $debug;
    my $frozen_request = freeze($request);
    # ...
    # the request is magically transported over to ... ourselves
    # ...
    my $response = execute_request( thaw $frozen_request );
    warn "RESPONSE=".Dumper($response) if $debug;
    my $frozen_response = freeze($response);
    # ...
    # the response is magically transported back to ... ourselves
    # ...
    return thaw($frozen_response);
}


1;
