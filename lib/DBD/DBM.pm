#######################################################################
#
#  DBD::DBM - a simple DBI driver for DBM files
#
#  Copyright (C) 2004 by Jeff Zucker < jzucker AT cpan.org >
#
#  All rights reserved.
#
#  You may distribute this module under the terms of either the GNU
#  General Public License or the Artistic License, as specified in
#  the Perl README file.
#
#######################################################################
require 5.005_03;
use strict;

package DBD::DBM;

use DBD::File ();
use vars qw($VERSION $ATTRIBUTION);
use base qw( DBD::File );

$VERSION = "0.01";
$ATTRIBUTION = "DBD::DBM by Jeff Zucker";

package DBD::DBM::dr;
$DBD::DBM::dr::imp_data_size = 0;
@DBD::DBM::dr::ISA = qw(DBD::File::dr);

package DBD::DBM::db;
$DBD::DBM::db::imp_data_size = 0;
@DBD::DBM::db::ISA = qw(DBD::File::db);

package DBD::DBM::st;
$DBD::DBM::st::imp_data_size = 0;
@DBD::DBM::st::ISA = qw(DBD::File::st);

package DBD::DBM::Statement;
use base qw( DBD::File::Statement );

use Fcntl;
#   AnyDBM_File defaults ISA to (NDBM_File DB_File GDBM_File SDBM_File ODBM_File)
#   ideally we'd prefer DB_File but we don't want to mess with @ISA ourselves
#   because the application using us may have already changed it
use AnyDBM_File;

sub open_table ($$$$$) {
    # NEED TO ADD FILE LOCKING
    my($self, $data, $table, $createMode, $lockMode) = @_;
    my $dbh = $data->{Database};
    my $file = $table || $self->{tables}->[0]->{name};
    my $open_mode = O_RDONLY;
       $open_mode = O_RDWR         if $lockMode;
       $open_mode = O_RDWR|O_CREAT|O_TRUNC if $createMode;
    my %h;
    die "Cannot CREATE '$file', already exists!"
        if $createMode and (-e "$file.pag" or -e "$file.dir");
    my $dbm_type = $dbh->{dbm_type} || 'AnyDBM_File';
    if ($dbm_type ne 'AnyDBM_File') {
        require "$dbm_type.pm";
        $dbh->STORE(dbm_type => $dbm_type);
    }
    eval { tie(%h, $dbm_type, $file, $open_mode, 0666) };
    die "Cannot tie file '$file': $@" if $@;
    my $tbl = {
	file      => $file,
        hash      => \%h,
	col_nums  => {dkey=>0,dval=>1},
	col_names => ['dkey','dval'],
    };
    my $class = ref($self);
    $class =~ s/::Statement/::Table/;
    bless($tbl, $class);
    $tbl;
}

# DELETE is only needed for backward compat with old SQL::Statement
# can remove when next SQL::Statement is released
sub DELETE ($$$) {
    my($self, $data, $params) = @_;
    my $dbh   = $data->{Database};
    my($table,$tname,@where_args);
    if ($dbh->{Driver}->{statement_version}) {
       my($eval,$all_cols) = $self->open_tables($data, 0, 1);
       return undef unless $eval;
       $eval->params($params);
       $self->verify_columns($eval, $all_cols);
       $table = $eval->table($self->tables(0)->name());
       @where_args = ($eval,$self->tables(0)->name());
    }
    else {
        $table = $self->open_tables($data, 0, 1);
        @where_args = ($table);
    }
    my($affected) = 0;
    while (my $array = $table->fetch_row($data)) {
        if ($self->eval_where(@where_args,$array)) {
            ++$affected;
            $table->delete_one_row($data,$array);
        }
    }
    return ($affected, 0);
}

package DBD::DBM::Table;
use base qw( DBD::File::Table );

sub drop ($$) {
    my($self,$data) = @_;
    untie %{$self->{hash}} if $self->{hash};
    unlink $self->{file}.'.dir' if -f $self->{file}.'.dir';
    unlink $self->{file}.'.pag' if -f $self->{file}.'.pag';
    unlink $self->{file}.'.db' if -f $self->{file}.'.db'; # Berzerkeley
    # put code to delete lockfile here
    return 1;
}
sub fetch_row ($$$) {
    my($self, $data, $row) = @_;
    my @ary = each %{$self->{hash}};
    return undef unless defined $ary[0];
    return @ary if wantarray;
    return \@ary;
}
sub push_row ($$$) {
    my($self, $data, $row_aryref) = @_;
    $self->{hash}->{$row_aryref->[0]}=$row_aryref->[1];
    1;
}
# optimized for hash-lookup, fetches without looping
sub fetch_one_row {
    my($self,$key_only,$value) = @_;
    return $self->{col_names}->[0] if $key_only;
    return $self->{hash}->{$value};
}
# "delete_one_row" seems to work within the each loop through the hash
# "update_one_row" does not
sub delete_one_row {
    my($self,$data,$aryref) = @_;
    delete $self->{hash}->{$aryref->[0]};
}
sub DESTROY {
    # code to release lock goes here
}
sub truncate {}
sub seek {}
sub push_names { 1; }
1;
__END__

=head1 NAME

DBD::DBM - simple DBI driver for DBM files

=head1 SYNOPSIS

    use DBI;
    $dbh = DBI->connect("DBI:DBM:", undef, undef);
    $dbh = DBI->connect("DBI:DBM:", undef, undef, { dbm_type => 'ODBM_File' });
    $dbh = DBI->connect("DBI:DBM(dbm_type=ODBM_File):", undef, undef);

=head1 DESCRIPTION

See L<DBI(3)> for details on DBI, L<SQL::Statement(3)> for details on
SQL::Statement and L<DBD::CSV(3)> or L<DBD::IniFile(3)> for example
drivers.

=head1 AUTHOR AND COPYRIGHT

This module was written and maintained by

      Jeff Zucker
      <jeff@vpservices.com>

Copyright (C) 2004 by Jeff Zucker

All rights reserved.

You may distribute this module under the terms of either the GNU
General Public License or the Artistic License, as specified in
the Perl README file.

=head1 SEE ALSO

L<DBI(3)>

=cut

