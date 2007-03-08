package DBI::Gofer::Transport::Base;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;
use warnings;

use Storable qw(nfreeze thaw);

use base qw(DBI::Util::_accessor);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);


__PACKAGE__->mk_accessors(qw(
    trace
    go_policy
));


sub _init_trace { $ENV{DBI_GOFER_TRACE} || 0 }


sub new {
    my ($class, $args) = @_;
    $args->{trace} ||= $class->_init_trace;
    my $self = bless {}, $class;
    $self->$_( $args->{$_} ) for keys %$args;
    return $self;
}



sub freeze_data {
    my ($self, $data, $skip_trace) = @_;
    $self->_dump("freezing ".ref($data), $data)
        if !$skip_trace and $self->trace;
    local $Storable::forgive_me = 1; # for CODE refs etc
    my $frozen = eval { nfreeze($data) };
    if ($@) {
        chomp $@;
        die "Error freezing ".ref($data)." object: $@";
    }
    return $frozen;
}   

sub thaw_data {
    my ($self, $frozen_data, $skip_trace) = @_;
    my $data = eval { thaw($frozen_data) };
    if ($@) {
        chomp(my $err = $@);
        $self->_dump("bad data",$frozen_data);
        die "Error thawing object: $err";
    }
    $self->_dump("thawing ".ref($data), $data)
        if !$skip_trace and $self->trace;
    return $data;
}



sub _dump {
    my ($self, $label, $data) = @_;
    require Data::Dumper;
    local $Data::Dumper::Indent    = 1;
    local $Data::Dumper::Terse     = 1;
    local $Data::Dumper::Useqq     = 1;
    local $Data::Dumper::Sortkeys  = 1;
    local $Data::Dumper::Quotekeys = 0;
    local $Data::Dumper::Deparse   = 0;
    local $Data::Dumper::Purity    = 0;
    $self->trace_msg("$label=".Data::Dumper::Dumper($data));
}


sub trace_msg {
    my ($self, $msg, $min_level) = @_;
    $min_level = 1 unless defined $min_level;
    # modeled on DBI's trace_msg method
    return 0 if $self->trace < $min_level;
    return DBI->trace_msg($msg, 0); # 0 to force logging even if DBI trace not enabled
}

1;

=head1 AUTHOR AND COPYRIGHT

The DBD::Gofer, DBD::Gofer::* and DBI::Gofer::* modules are
Copyright (c) 2007 Tim Bunce. Ireland.  All rights reserved.

You may distribute under the terms of either the GNU General Public License or
the Artistic License, as specified in the Perl README file.

