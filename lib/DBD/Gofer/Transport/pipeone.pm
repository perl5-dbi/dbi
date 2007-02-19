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
use Config;

use base qw(DBD::Gofer::Transport::Base);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

__PACKAGE__->mk_accessors(qw(
    connection_info
    response_info
)); 


my $this_perl = $^X;
$this_perl .= $Config{_exe}
    if $^O ne 'VMS' && $this_perl !~ m/$Config{_exe}$/i;


sub start_pipe_command {
    my ($self, $cmd) = @_;
    $cmd = [ $cmd ] unless ref $cmd eq 'ARRAY';

    # translate any SAMEPERL in cmd to $this_perl
    $_ eq 'SAMEPERL' and $_ = $this_perl
        for @$cmd;

    # if it's important that the subprocess uses the same
    # (versions of) modules as us then the caller should
    # set PERL5LIB itself.

    # limit various forms of insanity, for now
    local $ENV{DBI_TRACE};
    local $ENV{DBI_AUTOPROXY};
    local $ENV{DBI_PROFILE};

    my ($wfh, $rfh, $efh) = (gensym, gensym, gensym);
    my $pid = open3($wfh, $rfh, $efh, @$cmd)
        or die "error starting @$cmd: $!\n";
    $self->trace_msg("Started pid $pid: $cmd\n") if $self->trace;

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
    return join " ", map { "'$_'" } @{$connection_info->{cmd}};
}


sub transmit_request {
    my ($self, $request) = @_;

    my $info = eval { 
        my $frozen_request = $self->freeze_data($request);

        my $cmd = [ qw(SAMEPERL -MDBI::Gofer::Transport::pipeone -e run_one_stdio)];
        my $info = $self->start_pipe_command($cmd);

        my $wfh = delete $info->{wfh};
        # send frozen request
        print $wfh $frozen_request;
        # indicate that there's no more
        close $wfh
            or die "error writing to @$cmd: $!\n";

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
    my ($pid, $rfh, $efh, $cmd) = @{$info}{qw(pid rfh efh cmd)};

    waitpid $info->{pid}, 0
        or warn "waitpid: $!"; # XXX do something more useful?

    my $frozen_response = do { local $/; <$rfh> };
    my $stderr_msg      = do { local $/; <$efh> };

    if (not $frozen_response) { # no output on stdout at all
        return DBI::Gofer::Response->new({
            err    => 1,
            errstr => ref($self)." command (@$cmd) failed: $stderr_msg",
        }); 
    }

    # XXX need to be able to detect and deal with corruption
    $response = $self->thaw_data($frozen_response);

    if ($stderr_msg) {
        warn "STDERR message from @$cmd: $stderr_msg"; # XXX remove later
        $response->add_err(0, $stderr_msg);
    }

    return $response;
}


1;

__END__

=head1 NAME
    
DBD::Gofer::Transport::pipeone - DBD::Gofer client transport for testing

=head1 SYNOPSIS

  $original_dsn = "...";
  DBI->connect("dbi:Gofer:transport=pipeone;dsn=$original_dsn",...)

or, enable by setting the DBI_AUTOPROXY environment variable:

  export DBI_AUTOPROXY="dbi:Gofer:transport=pipeone"

=head1 DESCRIPTION

Connect via DBD::Gofer and execute each request by starting executing a subprocess.

This is, as you might imagine, spectacularly inefficient!

It's only intended for testing. Specifically it demonstrates that the server
side is completely stateless.

It also provides a base class for the much more useful L<DBD::Gofer::Transport::stream>
transport.

=head1 SEE ALSO

L<DBD::Gofer>

=cut

