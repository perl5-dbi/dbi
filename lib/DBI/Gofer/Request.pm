package DBI::Gofer::Request;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use base qw(DBI::Util::_accessor);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);


__PACKAGE__->mk_accessors(qw(
    connect_args
    dbh_method_call
    dbh_wantarray
    dbh_attributes
    dbh_last_insert_id_args
    sth_method_calls
    sth_result_attr
));

sub reset {
    my $self = shift;
    # remove everything except connect
    %$self = ( connect_args => $self->{connect_args} );
}

sub is_sth_request {
    return shift->{sth_result_attr};
}

sub init_request {
    my ($self, $method_and_args, $wantarray) = @_;
    $self->reset;
    $self->dbh_method_call($method_and_args);
    $self->dbh_wantarray($wantarray);
}

1;
