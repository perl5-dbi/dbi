package DBI::Gofer::Request;

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
    connect_args
    dbh_method_call
    dbh_wantarray
    dbh_attributes
    dbh_last_insert_id_args
    sth_method_calls
    sth_result_attr
));


sub new {
    my ($self, $args) = @_;
    $args->{version} ||= $VERSION;
    return $self->SUPER::new($args);
}


sub reset {
    my $self = shift;
    # remove everything except connect and version
    %$self = ( version => $self->{version}, connect_args => $self->{connect_args} );
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

sub summary_as_text {
    my $self = shift;
    my @s = '';

    my ($dsn, $attr) = @{ $self->connect_args };
    push @s, "dbh= connect('$dsn', , , { %{$attr||{}} ]} })";

    my ($meth, @args) = @{ $self->dbh_method_call };
    push @s, sprintf "dbh->%s(%s)", $meth, neat_list(\@args);

    for my $call (@{ $self->sth_method_calls || [] }) {
        my ($meth, @args) = @$call;
        push @s, sprintf "sth->%s(%s)", $meth, neat_list(\@args);
    }

    return join("\n\t", @s) . "\n";
}

1;

=head1 AUTHOR AND COPYRIGHT

The DBD::Gofer, DBD::Gofer::* and DBI::Gofer::* modules are
Copyright (c) 2007 Tim Bunce. Ireland.  All rights reserved.

You may distribute under the terms of either the GNU General Public License or
the Artistic License, as specified in the Perl README file.

