package DBD::Gofer::Transport::http;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;
use warnings;

use Carp;
use URI;
use LWP::UserAgent;
use HTTP::Request;

use base qw(DBD::Gofer::Transport::Base);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

__PACKAGE__->mk_accessors(qw(
    connection_info
    response_info
)); 

my $encoding = "binary";


sub transmit_request {
    my ($self, $request) = @_;

    my $info = eval { 
        my $frozen_request = $self->freeze_data($request);

        my $req = $self->{req} ||= do {
            my $url = $self->go_url || croak "No url specified";
            my $request = HTTP::Request->new(POST => $url);
            $request->content_type('application/x-perl-dbd-gofer-$encoding');
            $request;
        };
        my $ua = $self->{ua} ||= do {
            my $useragent = LWP::UserAgent->new(
                #timeout => XXX,
                env_proxy => 1, # XXX
            );
            $useragent->agent(join "/", __PACKAGE__, $DBI::VERSION, $VERSION);
            #$useragent->credentials( $netloc, $realm, $uname, $pass ); XXX
            $useragent->parse_head(0); # don't parse html head
            $useragent;
        };

        my $content = $frozen_request;
        $req->header('Content-Length' => length($content)); # in bytes
        $req->content($content);

        # Pass request to the user agent and get a response back
        my $res = $ua->request($req);
        $self->connection_info( $res );
    };
    if ($@) {
        my $response = DBI::Gofer::Response->new({ err => 1, errstr => $@ }); 
        $self->response_info($response);
    }
    else {
        $self->response_info(undef);
    }

    return 1;
}


sub receive_response {
    my $self = shift;

    my $response = $self->response_info;
    return $response if $response; # failed while starting

    my $res = $self->connection_info || die;

    if (not $res->is_success) {
        return DBI::Gofer::Response->new({
            err    => 1, # or 100_000 + $res->status_code?
            errstr => $res->status_line,
        }); 
    }

    my $frozen_response = $res->content;

    $response = $self->thaw_data($frozen_response);

    return $response;
}


1;

__END__
