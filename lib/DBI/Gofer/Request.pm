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
    dbh_connect_call
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
    %$self = ( version => $self->{version}, dbh_connect_call => $self->{dbh_connect_call} );
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
    my ($context) = @_;
    my @s = '';

    if ($context && %$context) {
        my @keys = sort keys %$context;
        push @s, join(", ", map { "$_=>".$context->{$_} } @keys);
    }

    my ($method, $dsn, $user, $pass, $attr) = @{ $self->dbh_connect_call };
    $method ||= 'connect_cached';
    $pass = '***' if defined $pass;
    my $tmp = '';
    if ($attr) { 
        $tmp = { %{$attr||{}} }; # copy so we can edit
        $tmp->{Password} = '***' if exists $tmp->{Password};
        $tmp = "{ ".neat_list([ %$tmp ])." }";
    }
    push @s, sprintf "dbh= $method(%s, %s)", neat_list([$dsn, $user, $pass]), $tmp;

    if (my $dbh_attr = $self->dbh_attributes) {
        push @s, sprintf "dbh->FETCH: %s", @$dbh_attr
            if @$dbh_attr;
    }

    my ($meth, @args) = @{ $self->dbh_method_call };
    my $args = neat_list(\@args);
    $args =~ s/\n+/ /g;
    push @s, sprintf "dbh->%s(%s)", $meth, $args;

    if (my $lii_args = $self->dbh_last_insert_id_args) {
        push @s, sprintf "dbh->last_insert_id(%s)", neat_list($lii_args);
    }

    for my $call (@{ $self->sth_method_calls || [] }) {
        my ($meth, @args) = @$call;
        ($args = neat_list(\@args)) =~ s/\n+/ /g;
        push @s, sprintf "sth->%s(%s)", $meth, $args;
    }

    if (my $sth_attr = $self->sth_result_attr) {
        push @s, sprintf "sth->FETCH: %s", %$sth_attr
            if %$sth_attr;
    }

    return join("\n\t", @s) . "\n";
}

1;

=head1 AUTHOR AND COPYRIGHT

The DBD::Gofer, DBD::Gofer::* and DBI::Gofer::* modules are
Copyright (c) 2007 Tim Bunce. Ireland.  All rights reserved.

You may distribute under the terms of either the GNU General Public License or
the Artistic License, as specified in the Perl README file.

