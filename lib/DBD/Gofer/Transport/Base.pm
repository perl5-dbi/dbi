package DBD::Gofer::Transport::Base;

#   $Id: Base.pm 8696 2007-01-24 23:12:38Z timbo $
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;
use warnings;

use Carp qw(cluck);
use Storable qw(freeze thaw);

use base qw(Class::Accessor::Fast);

our $VERSION = sprintf("0.%06d", q$Revision: 8696 $ =~ /(\d+)/o);

our $debug = $ENV{DBD_GOFER_TRACE} || 0;


__PACKAGE__->mk_accessors(qw(
    go_dsn
));


sub freeze_data {
    my ($self, $data, $skip_debug) = @_;
    $self->_dump("DBD_GOFER_TRACE freezing ".ref($data), $data)
        if $debug && not $skip_debug;
    local $Storable::forgive_me = 1; # for CODE refs etc
    return freeze($data);
}   

sub thaw_data {
    my ($self, $frozen_data, $skip_debug) = @_;
    my $data = thaw($frozen_data);
    $self->_dump("DBD_GOFER_TRACE thawing ".ref($data), $data)
        if $debug && not $skip_debug;
    return $data;
}


sub _dump {
    my ($self, $label, $data) = @_;
    require Data::Dumper;
    # XXX dd settings
    warn "$label=".Data::Dumper::Dumper($data);
}

1;
