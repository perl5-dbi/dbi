package DBD::Gofer::Transport::pipe;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;
use warnings;

use IPC::Open3 qw(open3);
use Symbol qw(gensym);

use base qw(DBD::Gofer::Transport::Base);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

__PACKAGE__->mk_accessors(qw(
    response_info
)); 


sub transmit_request {
    my ($self, $request) = @_;

    my $info = eval { 
        my $frozen_request = $self->freeze_data($request);

        local $ENV{DBI_TRACE};
        local $ENV{DBI_AUTOPROXY};
        local $ENV{DBI_PROFILE};
        local $ENV{PERL5LIB} = join ":", @INC;
        my $cmd = "perl -MDBI::Gofer::Transport::pipe -e run_one_stdio";

        my ($wfh, $rfh, $efh) = (gensym, gensym, gensym);
        my $pid = open3($wfh, $rfh, $efh, $cmd)
            or die "error starting subprocess: $!\n";

        # send frozen request
        print $wfh $frozen_request;
        # indicate that there's no more
        close $wfh
            or die "error writing to subprocess: $!\n";

        # so far so good. return the state info
        { pid=>$pid, rfh=>$rfh, efh=>$efh };
    };
    if ($@) {
    warn $@;
        $info = {};
        $info->{response} = DBI::Gofer::Response->new({
            err    => 1,
            errstr => $@,
        }); 
    }

    # record what we need to get a response, ready for receive_response()
    $self->response_info( $info );

    return 1;
}


sub receive_response {
    my $self = shift;

    my $info = $self->response_info || die;
    my ($response, $pid, $rfh, $efh) = @{$info}{qw(response pid rfh efh)};

    return $response if $response; # failed while starting

    waitpid $info->{pid}, 0
        or warn "waitpid: $!"; # XXX do something more useful?

    my $frozen_response = do { local $/; <$rfh> };
    my $stderr_msg      = do { local $/; <$efh> };

    if (not $frozen_response) { # no output on stdout at all
        return DBI::Gofer::Response->new({
            err    => 1,
            errstr => "pipe command failed: $stderr_msg",
        }); 
    }
    warn "STDERR message: $stderr_msg" if $stderr_msg; # XXX do something more useful
    #warn DBI::neat($frozen_response);

    # XXX may be corrupt
    $response = $self->thaw_data($frozen_response);

    return $response;
}


1;

__END__

Spectacularly inefficient.

Intended as a test of the truely stateless nature of the Gofer servers,
and an example implementation of a transport that talks to another process.
