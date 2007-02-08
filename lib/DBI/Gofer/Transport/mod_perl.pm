package DBI::Gofer::Transport::mod_perl;

use strict;
use warnings;

use DBI::Gofer::Execute qw(execute_request);

use Apache::Constants qw(OK);

use base qw(DBI::Gofer::Transport::Base);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

my $transport = __PACKAGE__->new();


sub handler {
    my $r = shift;
    my $r_dir_config = $r->dir_config; # cache it as it's relatively expensive

    $r->read(my $frozen_request, $r->header_in('Content-length'));

    my $response = execute_request( $transport->thaw_data($frozen_request) );

    my $frozen_response = $transport->freeze_data($response);

    print $frozen_response;

    return Apache::Constants::OK;
}
