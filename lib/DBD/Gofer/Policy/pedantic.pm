package DBD::Gofer::Policy::pedantic;

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

# the 'pedantic' policy is the same as the Base policy

1;
