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
    go_perl
    go_persist
)); 

my $persist_all = 5;
my %persist;

sub nonblock;


sub _connection_key {
    my ($self) = @_;
    my $go_perl = $self->go_perl;
    return join "~", $self->go_url, ref $go_perl ? @$go_perl : $go_perl||"";
}


sub _connection_get {
    my ($self) = @_;

    my $persist = $self->go_persist; # = 0 can force non-caching
    $persist = $persist_all if not defined $persist;
    my $key = ($persist) ? $self->_connection_key : '';
    if ($persist{$key} && $self->_connection_check($persist{$key})) {
        DBI->trace_msg("reusing persistent connection $key");
        return $persist{$key};
    }

    my $connection = $self->_make_connection;

    if ($key) {
        %persist = () if keys %persist > $persist_all; # XXX quick hack to limit subprocesses
        $persist{$key} = $connection;
    }

    return $connection;
}


sub _connection_check {
    my ($self, $connection) = @_;
    $connection ||= $self->connection_info;
    my $pid = $connection->{pid};
    return (kill 0, $pid);
}


sub _connection_kill {
    my ($self) = @_;
    my $connection = $self->connection_info;
    my ($pid, $wfh, $rfh, $efh) = @{$connection}{qw(pid wfh rfh efh)};
    # closing the write file handle should be enough, generally
    close $wfh;
    # in code cases in future we may want to be more aggressive
    #close $rfh; close $efh; kill 15, $pid
    # but deleting from the persist cache...
    delete $persist{ $self->_connection_key };
    # ... and removing the connection_info should suffice
    $self->connection_info( undef );
    return;
}


sub _make_connection {
    my ($self) = @_;

    my $cmd = [qw(SAMEPERL -MDBI::Gofer::Transport::stream -e run_stdio_hex)];
    if (my $perl = $self->go_perl) {
        # user can override the perl to be used, either with an array ref
        # containing the command name and args to use, or with a string
        # (ie via the DSN) in which case, to enable args to be passed,
        # we split on two or more consecutive spaces (otherwise the path
        # to perl couldn't contain a space itself).
        splice @$cmd, 0, 1, (ref $perl ? @$perl : split /\s{2,}/,$perl);
    }

    #push @$cmd, "DBI_TRACE=2=/tmp/goferstream.log", "sh", "-c";
    if (my $url = $self->go_url) {
        die "Only 'ssh:user\@host' style url supported by this transport"
            unless $url =~ s/^ssh://;
        $cmd->[0] = 'perl' unless $self->go_perl; # don't use SAMEPERL on remote system
        my $ssh = $url;
        my $setup_env = join "||", map { "source $_ 2>/dev/null" } qw(.bash_profile .bash_login .profile);
        #my $setup_env = "{ . .bash_profile || . .bash_login || . .profile; } 2>/dev/null";
        my $setup = $setup_env.q{; exec "$@"};
        # -x not only 'Disables X11 forwarding' but also makes connections *much* faster
        unshift @$cmd, qw(ssh -xq), split(' ', $ssh), qw(bash -c), $setup;
    }

    DBI->trace_msg("new connection: @$cmd");

    # XXX add a handshake - some message from DBI::Gofer::Transport::stream that's
    # sent as soon as it starts that we can wait for to report success - and soak up
    # and report useful warnings etc from ssh before we get it? Increases latency though.
    my $connection = $self->start_pipe_command($cmd);
    nonblock($connection->{efh});
    return $connection;
}


sub transmit_request {
    my ($self, $request) = @_;

    eval { 
        my $connection = $self->connection_info || do {
            my $con = $self->_connection_get;
            $self->connection_info( $con );
            #warn ''.$self->cmd_as_string;
            $con;
        };

        my $frozen_request = unpack("H*", $self->freeze_data($request));
        $frozen_request .= "\n";

        my $wfh = $connection->{wfh};
        # send frozen request
        print $wfh $frozen_request # autoflush enabled
            or do {
                # XXX should make new connection and retry
                $self->_connection_kill;
                die "Error sending request: $!";
            };
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

With a C<url=ssh:username@host.example.com> parameter it uses ssh to launch the subprocess
on a remote system. That's much more useful!

It gives you secure remote access to DBI databases on any system you can login to.
Using ssh also gives you optional compression and many other features (see the
ssh manual for how to configure that and many other options via ~/.ssh/config file).

The actual command invoked is something like:

  ssh -xq ssh:username@host.example.com bash -c $setup $run

where $run is the command shown above, and $command is

  . .bash_profile 2>/dev/null || . .bash_login 2>/dev/null || . .profile 2>/dev/null; exec "$@"

which is trying (in a limited and fairly unportable way) to setup the environment
(PATH, PERL5LIB etc) as it would be if you had logged in to that system.

The "C<perl>" used in the command will default to the value of $^X when not using ssh.
On most systems that's the full path to the perl that's currently executing.


=head1 PERSISTENCE

Currently gofer stream connections persist (remain connected) after all
database handles have been disconnected. This makes later connections in the
same process very fast.

Currently up to 5 different gofer stream connections (based on url) can
persist.  If more than 5 are in the cache when a new connection is made then
the cache is cleared before adding the new connection. Simple but effective.

=head1 TO DO

Document go_perl attribute

Automatically reconnect (within reason) if there's a transport error.

Decide on default for persistent connection - on or off? limits? ttl?

=head1 SEE ALSO

L<DBD::Gofer>

=cut

