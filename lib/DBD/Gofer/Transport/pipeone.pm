package DBD::Gofer::Transport::pipeone;

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
    connection_info
    response_info
)); 


sub start_pipe_command {
    my ($self, $cmd) = @_;
    $cmd = [ $cmd ] unless ref $cmd eq 'ARRAY';

    # ensure subprocess will use the same modules as us
    local $ENV{PERL5LIB} = join ":", @INC;

    # limit various forms of insanity, for now
    local $ENV{DBI_TRACE};
    local $ENV{DBI_AUTOPROXY};
    local $ENV{DBI_PROFILE};

    my ($wfh, $rfh, $efh) = (gensym, gensym, gensym);
    my $pid = open3($wfh, $rfh, $efh, @$cmd)
        or die "error starting $cmd: $!\n";
    warn "Started pid $pid: $cmd\n" if $self->trace;

    return {
        cmd=>$cmd,
        pid=>$pid,
        wfh=>$wfh, rfh=>$rfh, efh=>$efh,
    };
}


sub cmd_as_string {
    my $self = shift;
    # XXX meant to return a prroperly shell-escaped string suitable for system
    # but its only for debugging so that can wait
    my $connection_info = $self->connection_info;
    return join " ", @{$connection_info->{cmd}};
}


sub transmit_request {
    my ($self, $request) = @_;

    my $info = eval { 
        my $frozen_request = $self->freeze_data($request);

        my $cmd = [qw(perl -MDBI::Gofer::Transport::pipeone -e run_one_stdio)];
        my $info = $self->start_pipe_command($cmd);

        my $wfh = delete $info->{wfh};
        # send frozen request
        print $wfh $frozen_request;
        # indicate that there's no more
        close $wfh
            or die "error writing to $cmd: $!\n";

        $info; # so far so good. return the state info
    };
    if ($@) {
        my $response = DBI::Gofer::Response->new({ err => 1, errstr => $@ }); 
        $self->response_info($response);
    }
    else {
        $self->response_info(undef);
    }

    # record what we need to get a response, ready for receive_response()
    $self->connection_info( $info );

    return 1;
}


sub receive_response {
    my $self = shift;

    my $response = $self->response_info;
    return $response if $response; # failed while starting

    my $info = $self->connection_info || die;
    my ($pid, $rfh, $efh) = @{$info}{qw(pid rfh efh)};

    waitpid $info->{pid}, 0
        or warn "waitpid: $!"; # XXX do something more useful?

    my $frozen_response = do { local $/; <$rfh> };
    my $stderr_msg      = do { local $/; <$efh> };

    if (not $frozen_response) { # no output on stdout at all
        return DBI::Gofer::Response->new({
            err    => 1,
            errstr => "pipeone command failed: $stderr_msg",
        }); 
    }
    warn "STDERR message: $stderr_msg" if $stderr_msg; # XXX do something more useful

    # XXX need to be able to detect and deal with corruption
    $response = $self->thaw_data($frozen_response);

    return $response;
}


1;

__END__

Spectacularly inefficient.

Intended as a test of the truely stateless nature of the Gofer servers,
and an example implementation of a transport that talks to another process.
