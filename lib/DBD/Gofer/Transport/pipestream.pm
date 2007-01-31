package DBD::Gofer::Transport::pipestream;

#   $Id: pipeone.pm 8748 2007-01-29 22:49:42Z timbo $
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;
use warnings;

use Carp;
use Fcntl;

use base qw(DBD::Gofer::Transport::pipeone);

our $VERSION = sprintf("0.%06d", q$Revision: 8748 $ =~ /(\d+)/o);


sub nonblock;

sub transmit_request {
    my ($self, $request) = @_;

    eval { 

        my $connection = $self->connection_info;
        if (not $connection || ($connection->{pid} && not kill 0, $connection->{pid})) {
            my $cmd = "perl -MDBI::Gofer::Transport::pipestream -e run_stdio_hex";
            #$cmd = "DBI_TRACE=2=/tmp/pipestream.log $cmd";
            $connection = $self->start_pipe_command($cmd);
            nonblock($connection->{efh});
            $self->connection_info($connection);
        }

        my $frozen_request = unpack("H*", $self->freeze_data($request));
        $frozen_request .= "\n";

        my $wfh = $connection->{wfh};
        # send frozen request
        print $wfh $frozen_request # autoflush enabled
            or die "Error sending request: $!";
        warn "Request: $frozen_request" if $self->trace >= 3;
    };
    if ($@) {
        my $response = DBI::Gofer::Response->new({ err => 1, errstr => $@ }); 
        $self->response_info($response);
        # return undef ?
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

    my $connection = $self->connection_info || die;
    my ($pid, $rfh, $efh) = @{$connection}{qw(pid rfh efh)};

    my $frozen_response = <$rfh>; # always one line
    my $stderr_msg      = do { local $/; <$efh> }; # nonblocking

    chomp $stderr_msg if $stderr_msg;

    if (not $frozen_response) { # no output on stdout at all
    warn "STDERR err message: $stderr_msg" if $stderr_msg; # XXX do something more useful
        return DBI::Gofer::Response->new({
            err    => 1,
            errstr => "Error reading from $connection->{cmd}: $stderr_msg",
        }); 
    }
    chomp $frozen_response if $frozen_response;
    warn "STDERR additional message: $stderr_msg" if $stderr_msg; # XXX do something more useful
    #warn DBI::neat($frozen_response);

    # XXX need to be able to detect and deal with corruption
    $response = $self->thaw_data(pack("H*",$frozen_response));

    return $response;
}


# nonblock($fh) puts filehandle into nonblocking mode
sub nonblock {
  my $fh = shift;
  my $flags = fcntl($fh, F_GETFL, 0)
        or croak "Can't get flags for filehandle $fh: $!";
  fcntl($fh, F_SETFL, $flags | O_NONBLOCK)
        or croak "Can't make filehandle $fh nonblocking: $!";
}

1;

__END__

