# -*- perl -*-
#
#   DBD::Mem - A DBI driver for in-memory tables
#
#  This module is currently maintained by
#
#      Jens Rehsack
#
#  Copyright (C) 2016 by Jens Rehsack
#
#  All rights reserved.
#
#  You may distribute this module under the terms of either the GNU
#  General Public License or the Artistic License, as specified in
#  the Perl README file.

require 5.008;
use strict;

#################
package DBD::Mem;
#################
use base qw( DBI::DBD::SqlEngine );
use vars qw($VERSION $ATTRIBUTION $drh);
$VERSION     = '0.001';
$ATTRIBUTION = 'DBD::Mem by Jens Rehsack';

# no need to have driver() unless you need private methods
#
sub driver ($;$)
{
    my ( $class, $attr ) = @_;
    return $drh if ($drh);

    # do the real work in DBI::DBD::SqlEngine
    #
    $attr->{Attribution} = 'DBD::Mem by Jens Rehsack';
    $drh = $class->SUPER::driver($attr);

    return $drh;
}

sub CLONE
{
    undef $drh;
}

#####################
package DBD::Mem::dr;
#####################
$DBD::Mem::dr::imp_data_size = 0;
@DBD::Mem::dr::ISA           = qw(DBI::DBD::SqlEngine::dr);

# you could put some :dr private methods here

# you may need to over-ride some DBI::DBD::SqlEngine::dr methods here
# but you can probably get away with just letting it do the work
# in most cases

#####################
package DBD::Mem::db;
#####################
$DBD::Mem::db::imp_data_size = 0;
@DBD::Mem::db::ISA           = qw(DBI::DBD::SqlEngine::db);

use Carp qw/carp/;

sub set_versions
{
    my $this = $_[0];
    $this->{mem_version} = $DBD::Mem::VERSION;
    return $this->SUPER::set_versions();
}

sub init_valid_attributes
{
    my $dbh = shift;

    # define valid private attributes
    #
    # attempts to set non-valid attrs in connect() or
    # with $dbh->{attr} will throw errors
    #
    # the attrs here *must* start with mem_ or foo_
    #
    # see the STORE methods below for how to check these attrs
    #
    $dbh->{mem_valid_attrs} = {
        mem_version        => 1,    # verbose DBD::Mem version
        mem_valid_attrs    => 1,    # DBD::Mem::db valid attrs
        mem_readonly_attrs => 1,    # DBD::Mem::db r/o attrs
        mem_meta           => 1,    # DBD::Mem public access for f_meta
        mem_tables         => 1,    # DBD::Mem public access for f_meta
    };
    $dbh->{mem_readonly_attrs} = {
        mem_version        => 1,    # verbose DBD::Mem version
        mem_valid_attrs    => 1,    # DBD::Mem::db valid attrs
        mem_readonly_attrs => 1,    # DBD::Mem::db r/o attrs
        mem_meta           => 1,    # DBD::Mem public access for f_meta
    };

    $dbh->{mem_meta} = "mem_tables";

    return $dbh->SUPER::init_valid_attributes();
}

sub get_mem_versions
{
    my ( $dbh, $table ) = @_;
    $table ||= '';

    my $meta;
    my $class = $dbh->{ImplementorClass};
    $class =~ s/::db$/::Table/;
    $table and ( undef, $meta ) = $class->get_table_meta( $dbh, $table, 1 );
    $meta or ( $meta = {} and $class->bootstrap_table_meta( $dbh, $meta, $table ) );

    return sprintf( "%s using %s", $dbh->{mem_version}, $AnyData2::VERSION );
}

package DBD::Mem::st;

use strict;
use warnings;

our $imp_data_size = 0;
our @ISA           = qw(DBI::DBD::SqlEngine::st);

############################
package DBD::Mem::Statement;
############################

@DBD::Mem::Statement::ISA = qw(DBI::DBD::SqlEngine::Statement);


sub open_table ($$$$$)
{
    my ( $self, $data, $table, $createMode, $lockMode ) = @_;

    my $class = ref $self;
    $class =~ s/::Statement/::Table/;

    my $flags = {
                  createMode => $createMode,
                  lockMode   => $lockMode,
                };
    if( defined( $data->{Database}->{mem_table_data}->{$table} ) && $data->{Database}->{mem_table_data}->{$table})
    {
        my $t = $data->{Database}->{mem_tables}->{$table};
        $t->seek( $data, 0, 0 );
        return $t;
    }

    return $self->SUPER::open_table($data, $table, $createMode, $lockMode);
}

# ====== DataSource ============================================================

package DBD::Mem::DataSource;

use strict;
use warnings;

use Carp;

@DBD::Mem::DataSource::ISA = "DBI::DBD::SqlEngine::DataSource";

sub complete_table_name ($$;$)
{
    my ( $self, $meta, $table, $respect_case ) = @_;
    $table;
}

sub open_data ($)
{
    my ( $self, $meta, $attrs, $flags ) = @_;
    defined $meta->{data_tbl} or $meta->{data_tbl} = [];
}

########################
package DBD::Mem::Table;
########################

# shamelessly stolen from SQL::Statement::RAM

use Carp qw/croak/;

@DBD::Mem::Table::ISA = qw(DBI::DBD::SqlEngine::Table);

use Carp qw(croak);

sub new
{
    #my ( $class, $tname, $col_names, $data_tbl ) = @_;
    my ( $class, $data, $attrs, $flags ) = @_;
    my $self = $class->SUPER::new($data, $attrs, $flags);

    my $meta = $self->{meta};
    $self->{records} = $meta->{data_tbl};
    $self->{index} = 0;

    $self;
}

sub bootstrap_table_meta
{
    my ( $self, $dbh, $meta, $table ) = @_;

    defined $meta->{sql_data_source} or $meta->{sql_data_source} = "DBD::Mem::DataSource";

    $meta;
}

sub fetch_row
{
    my ( $self, $data ) = @_;

    return $self->{row} =
        ( $self->{records} and ( $self->{index} < scalar( @{ $self->{records} } ) ) )
      ? [ @{ $self->{records}->[ $self->{index}++ ] } ]
      : undef;
}

sub push_row
{
    my ( $self, $data, $fields ) = @_;
    my $currentRow = $self->{index};
    $self->{index} = $currentRow + 1;
    $self->{records}->[$currentRow] = $fields;
    return 1;
}

sub truncate
{
    my $self = shift;
    return splice @{ $self->{records} }, $self->{index}, 1;
}

sub push_names
{
    my ( $self, $data, $names ) = @_;
    my $meta = $self->{meta};
    $meta->{col_names} = $self->{col_names}     = $names;
    $self->{org_col_names} = [ @{$names} ];
    $self->{col_nums} = {};
    $self->{col_nums}{ $names->[$_] } = $_ for ( 0 .. scalar @$names - 1 );
}

sub drop ($)
{
    my ($self, $data) = @_;
    delete $data->{Database}{sql_meta}{$self->{table}};
    return 1;
} # drop

sub seek
{
    my ( $self, $data, $pos, $whence ) = @_;
    return unless defined $self->{records};

    my ($currentRow) = $self->{index};
    if ( $whence == 0 )
    {
        $currentRow = $pos;
    }
    elsif ( $whence == 1 )
    {
        $currentRow += $pos;
    }
    elsif ( $whence == 2 )
    {
        $currentRow = @{ $self->{records} } + $pos;
    }
    else
    {
        croak $self . "->seek: Illegal whence argument ($whence)";
    }

    $currentRow < 0 and
        croak "Illegal row number: $currentRow";
    $self->{index} = $currentRow;
}

1;
