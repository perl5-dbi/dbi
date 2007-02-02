package DBI::Gofer::Response;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use base qw(DBI::Util::_accessor);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

__PACKAGE__->mk_accessors(qw(
    rv
    err
    errstr
    state
    last_insert_id
    sth_resultsets
    warnings
));


sub add_err {
    my ($self, $err, $errstr, $state, $trace) = @_;
    chomp $errstr if $errstr;
    $state ||= '';
    warn "add_err($err, $errstr, $state)" if $trace and $errstr || $err;

    # acts like the DBI's set_err method.
    # this code copied from DBI::PurePerl's set_err method.

    my ($r_err, $r_errstr, $r_state) = ($self->{err}, $self->{errstr}, $self->{state});

    if ($r_errstr) {
        $r_errstr .= sprintf " [err was %s now %s]", $r_err, $err
                if $r_err && $err;
        $r_errstr .= sprintf " [state was %s now %s]", $r_state, $state
                if $r_state and $r_state ne "S1000" && $state;
        $r_errstr .= "\n$errstr";
    }   
    else { 
        $r_errstr = $errstr;
    }

    # assign if higher priority: err > "0" > "" > undef
    my $err_changed;
    if ($err                 # new error: so assign
        or !defined $r_err   # no existing warn/info: so assign
           # new warn ("0" len 1) > info ("" len 0): so assign
        or defined $err && length($err) > length($r_err)
    ) {
        $r_err = $err;
        ++$err_changed;
    }

    $r_state = ($state eq "00000") ? "" : $state
        if $state && $err_changed;

    ($self->{err}, $self->{errstr}, $self->{state}) = ($r_err, $r_errstr, $r_state);

    return undef;
}


1;
