package DBI::Gofer::Response;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;

use DBI qw(neat neat_list);

use base qw(DBI::Util::_accessor);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

__PACKAGE__->mk_accessors(qw(
    version
    rv
    err
    errstr
    state
    last_insert_id
    dbh_attributes
    sth_resultsets
    warnings
));


sub new {
    my ($self, $args) = @_;
    $args->{version} ||= $VERSION;
    chomp $args->{errstr} if $args->{errstr};
    return $self->SUPER::new($args);
}   


sub add_err {
    my ($self, $err, $errstr, $state, $trace) = @_;

    # acts like the DBI's set_err method.
    # this code copied from DBI::PurePerl's set_err method.

    chomp $errstr if $errstr;
    $state ||= '';
    warn "add_err($err, $errstr, $state)" if $trace and $errstr || $err;

    my ($r_err, $r_errstr, $r_state) = ($self->{err}, $self->{errstr}, $self->{state});

    if ($r_errstr) {
        $r_errstr .= sprintf " [err was %s now %s]", $r_err, $err
                if $r_err && $err && $r_err ne $err;
        $r_errstr .= sprintf " [state was %s now %s]", $r_state, $state
                if $r_state and $r_state ne "S1000" && $state && $r_state ne $state;
        $r_errstr .= "\n$errstr" if $r_errstr ne $errstr;
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


sub summary_as_text {
    my $self = shift;
    my ($rv, $err, $errstr, $state) = ($self->{rv}, $self->{err}, $self->{errstr}, $self->{state});
    my @s = sprintf("rv=%s", (ref $rv) ? "[".neat_list($rv)."]" : $rv);
    $s[-1] .= sprintf(" err=%s errstr=%s", $err, neat($errstr)) if defined $err;
    for my $rs (@{$self->sth_resultsets || []}) {
        my ($rowset, $err, $errstr, $state)
            = @{$rs}{qw(rowset err errstr state)};
        my $summary = "rowset: ";
        if ($rowset || $rs->{NUM_OF_FIELDS} > 0) {
            $summary .= sprintf "%d rows, %d columns", scalar @{$rowset||[]}, $rs->{NUM_OF_FIELDS}
        }
        if (defined $err) {
            $summary .= sprintf(", err=%s errstr=%s", $err, neat($errstr))
        }
        push @s, $summary;
    }
    return join("\n\t", @s). "\n";
}


1;

=head1 AUTHOR AND COPYRIGHT

The DBD::Gofer, DBD::Gofer::* and DBI::Gofer::* modules are
Copyright (c) 2007 Tim Bunce. Ireland.  All rights reserved.

You may distribute under the terms of either the GNU General Public License or
the Artistic License, as specified in the Perl README file.

