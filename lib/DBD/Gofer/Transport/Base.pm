package DBD::Gofer::Transport::Base;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;
use warnings;

use base qw(DBI::Gofer::Transport::Base);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

__PACKAGE__->mk_accessors(qw(
    trace
    go_dsn
    go_url
));


sub _init_trace { $ENV{DBD_GOFER_TRACE} || 0 }

1;

=head1 NAME

DBD::Gofer::Transport::Base - base class for DBD::Gofer client transports

=head1 SEE ALSO

L<DBD::Gofer>

and some example transports:

L<DBD::Gofer::Transport::stream>

L<DBD::Gofer::Transport::http>

L<DBI::Gofer::Transport::mod_perl>

=cut


=cut


