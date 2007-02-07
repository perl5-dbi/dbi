package DBI::Gofer::Transport::Base;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;
use warnings;

use Storable qw(freeze thaw);

use base qw(DBI::Util::_accessor);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);


__PACKAGE__->mk_accessors(qw(
    trace
));


sub _init_trace { $ENV{DBI_GOFER_TRACE} || 0 }


sub new {
    my ($class, $args) = @_;
    $args->{trace} ||= $class->_init_trace;
    my $self = bless {}, $class;
    $self->$_( $args->{$_} ) for keys %$args;
    return $self;
}



sub freeze_data {
    my ($self, $data, $skip_trace) = @_;
    $self->_dump("freezing ".ref($data), $data)
        if !$skip_trace and $self->trace;
    local $Storable::forgive_me = 1; # for CODE refs etc
    my $frozen = eval { freeze($data) };
    if ($@) {
        die "Error freezing ".ref($data)." object: $@";
    }
    return $frozen;
}   

sub thaw_data {
    my ($self, $frozen_data, $skip_trace) = @_;
    my $data = eval { thaw($frozen_data) };
    if ($@) {
        my $err = $@;
        $self->_dump("bad data",$frozen_data);
        die "Error thawing object: $err";
    }
    $self->_dump("thawing ".ref($data), $data)
        if !$skip_trace and $self->trace;
    return $data;
}



sub _dump {
    my ($self, $label, $data) = @_;
    require Data::Dumper;
    # XXX config dumper format
    warn "$label=".Data::Dumper::Dumper($data);
}

1;
