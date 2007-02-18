package DBD::Gofer::Transport::stream;

#   $Id$
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

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

__PACKAGE__->mk_accessors(qw(
)); 


sub nonblock;

sub transmit_request {
    my ($self, $request) = @_;

    eval { 

        my $connection = $self->connection_info;
        if (not $connection || ($connection->{pid} && not kill 0, $connection->{pid})) {
            my $cmd = [qw(SAMEPERL -MDBI::Gofer::Transport::stream -e run_stdio_hex)];
            #push @$cmd, "DBI_TRACE=2=/tmp/goferstream.log", "sh", "-c";
            if (my $url = $self->go_url) {
                die "Only 'ssh:user\@host' style url supported by this transport"
                    unless $url =~ s/^ssh://;
                my $ssh = $url;
                my $setup_env = join "||", map { "source $_ 2>/dev/null" }
                                    qw(.bash_profile .bash_login .profile);
                my $setup = $setup_env.q{; eval "$@"};
                $cmd->[0] = 'perl'; # don't use SAMEPERL on remote system
                unshift @$cmd, qw(ssh -q), split(' ', $ssh), qw(bash -c), $setup;
            }
            # XXX add a handshake - some message from DBI::Gofer::Transport::stream that's
            # sent as soon as it starts that we can wait for to report success - and soak up
            # and useful warnings etc from shh before we get it.
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
        $self->trace_msg("Request: $frozen_request\n") if $self->trace >= 3;
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

    # blocks till a newline has been read
    $! = 0;
    my $frozen_response = <$rfh>; # always one line
    my $frozen_response_errno = $!;

    # must read any stderr output _afterwards_
    # warnings during execution are caught and returned as part
    # of the response object. So stderr should be silent.
    my $stderr_msg = do { local $/; <$efh> }; # nonblocking

    # if we got no output on stdout at all then the command has
    # proably exited, possibly with an error to stderr.
    # Turn this situation into a reasonably useful DBI error.
    if (not $frozen_response or !chomp $frozen_response) {
        chomp $stderr_msg if $stderr_msg;
        my $msg = sprintf("Error reading from %s (pid %d%s): ",
            $self->cmd_as_string, $pid, (kill 0, $pid) ? "" : ", exited");
        $msg .= $stderr_msg || $frozen_response_errno;
        return DBI::Gofer::Response->new({ err => 1, errstr => $msg }); 
    }
    #warn DBI::neat($frozen_response);
    $self->trace_msg("Gofer stream stderr message: $stderr_msg\n")
        if $stderr_msg && $self->trace;

    # XXX need to be able to detect and deal with corruption
    $response = $self->thaw_data(pack("H*",$frozen_response));

    # add any stderr messages as a warning (ie PrintWarn)
    $response->add_err(0, $stderr_msg, undef, $self->trace)
        if $stderr_msg;

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

=head1 NAME
    
DBD::Gofer::Transport::stream - DBD::Gofer transport for stdio streaming

=head1 SYNOPSIS

  DBI->connect('dbi:Gofer:transport=stream;url=ssh:username@host.example.com;dsn=dbi:...',...)

or, enable by setting the DBI_AUTOPROXY environment variable:

  export DBI_AUTOPROXY='dbi:Gofer:transport=stream;url=ssh:username@host.example.com'

=head1 DESCRIPTION

Without the C<url=> parameter it launches a subprocess as

  perl -MDBI::Gofer::Transport::stream -e run_stdio_hex

and feeds requests into it and reads responses from it. But that's not very useful.

With a C<url=ssh:username@host.example.com> parameter it launches a subprocess as
something like

  ssh -q ssh:username@host.example.com bash -c $setup $run

where $run is the command shown above, and $command is

  source .bash_profile 2>/dev/null \
  || source .bash_login 2>/dev/null \
  || source .profile 2>/dev/null \
  ; eval "$@"

which is trying (in a limited an unportable way) to setup the environment
(PATH, PERL5LIB etc) as it would be if you had logged in to that system.

=head1 SEE ALSO

L<DBD::Gofer>

=cut

