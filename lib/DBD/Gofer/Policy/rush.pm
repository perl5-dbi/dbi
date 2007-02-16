package DBD::Gofer::Policy::rush;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;
use warnings;

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

use base qw(DBD::Gofer::Policy::Base);

__PACKAGE__->create_default_policy_subs({

    # don't skip the connect check since that also sets dbh attributes
    # although this makes connect more expensive, that's partly offset
    # by skip_ping=>1 below, which makes connect_cached very fast.
    skip_connect_check => 1,

    # most code doesn't rely on sth attributes being set after prepare
    skip_prepare_check => 1,

    # ping is almost meaningless for DBD::Gofer and most transports anyway
    skip_ping => 1,

    # don't update dbh attributes at all
    dbh_attribute_update => 'none',
    dbh_attribute_list => undef,

});


1;
