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

use base qw(Class::Accessor::Fast);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

sub _init_trace { $ENV{DBI_GOFER_TRACE} || 0 }


__PACKAGE__->mk_accessors(qw(
    trace
    go_dsn
));


sub new {
    my ($class, $args) = @_;
    $args->{trace} ||= $class->_init_trace;
    return $class->SUPER::new($args);
}


sub freeze_data {
    my ($self, $data, $skip_trace) = @_;
    $self->_dump("freezing ".ref($data), $data)
        if !$skip_trace and $self->trace;
    local $Storable::forgive_me = 1; # for CODE refs etc
    return freeze($data);
}   

sub thaw_data {
    my ($self, $frozen_data, $skip_trace) = @_;
    my $data = thaw($frozen_data);
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
