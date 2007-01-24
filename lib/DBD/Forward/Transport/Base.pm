package DBD::Forward::Transport::Base;

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

our $debug = $ENV{DBD_FORWARD_DEBUG} || 0;


__PACKAGE__->mk_accessors(qw(
    fwd_dsn
));


sub freeze_data {
    my ($self, $data) = @_;
    $self->_dump(ref($data), $data) if $debug;
    local $Storable::forgive_me = 1; # for CODE refs etc
    return freeze($data);
}   

sub thaw_data {
    my ($self, $frozen_data) = @_;
    local $Storable::forgive_me = 1; # for CODE refs etc
    my $data = thaw($frozen_data);
    $self->_dump(ref($data), $data) if $debug;
    return $data;
}


sub _dump {
    my ($self, $label, $data) = @_;
    require Data::Dumper;
    # XXX dd settings
    warn "$label=".Data::Dumper::Dumper($data);

}

1;
