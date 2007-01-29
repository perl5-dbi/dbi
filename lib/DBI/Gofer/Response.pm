package DBI::Gofer::Response;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use base qw(Class::Accessor::Fast);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

__PACKAGE__->mk_accessors(qw(
    rv
    err
    errstr
    state
    last_insert_id
    sth_resultsets
));

1;
