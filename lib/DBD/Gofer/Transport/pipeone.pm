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
    go_perl
)); 


sub new {
    my ($self, $args) = @_;
    $args->{go_perl} ||= [ $^X ];
    if (not ref $args->{go_perl}) {
        # user can override the perl to be used, either with an array ref
        # containing the command name and args to use, or with a string
        # (ie via the DSN) in which case, to enable args to be passed,
        # we split on two or more consecutive spaces (otherwise the path
        # to perl couldn't contain a space itself).
        $args->{go_perl} = [ split /\s{2,}/, $args->{go_perl} ];
    }
    return $self->SUPER::new($args);
}


sub start_pipe_command {
    my ($self, $cmd) = @_;
    $cmd = [ $cmd ] unless ref $cmd eq 'ARRAY';

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
    $self->trace_msg("Started pid $pid: @$cmd\n",0) if $self->trace;

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


sub transmit_request_by_transport {
    my ($self, $request) = @_;

    my $frozen_request = $self->freeze_data($request);

    my $cmd = [ @{$self->go_perl}, qw(-MDBI::Gofer::Transport::pipeone -e run_one_stdio)];
    my $info = $self->start_pipe_command($cmd);

    my $wfh = delete $info->{wfh};
    # send frozen request
    print $wfh $frozen_request;
    # indicate that there's no more
    close $wfh
        or die "error writing to @$cmd: $!\n";

    $self->connection_info( $info );
    return;
}


sub receive_response_by_transport {
    my $self = shift;

    my $info = $self->connection_info || die;
    my ($pid, $rfh, $efh, $cmd) = @{$info}{qw(pid rfh efh cmd)};

    my $frozen_response = do { local $/; <$rfh> };
    my $stderr_msg      = do { local $/; <$efh> };

    waitpid $info->{pid}, 0
        or warn "waitpid: $!"; # XXX do something more useful?

    die ref($self)." command (@$cmd) failed: $stderr_msg"
        if not $frozen_response; # no output on stdout at all

    # XXX need to be able to detect and deal with corruption
    my $response = $self->thaw_data($frozen_response);

    if ($stderr_msg) {
        # add stderr messages as warnings (for PrintWarn)
        $response->add_err(0, $stderr_msg, undef, $self->trace)
            # but ignore warning from old version of blib
            unless $stderr_msg =~ /^Using .*blib/ && "@$cmd" =~ /-Mblib/;
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

=head1 AUTHOR AND COPYRIGHT

The DBD::Gofer, DBD::Gofer::* and DBI::Gofer::* modules are
Copyright (c) 2007 Tim Bunce. Ireland.  All rights reserved.

You may distribute under the terms of either the GNU General Public License or
the Artistic License, as specified in the Perl README file.


=head1 SEE ALSO

L<DBD::Gofer>

=cut

