package DBI::Gofer::Transport::Base;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;
use warnings;

use base qw(DBI::Util::_accessor);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);


__PACKAGE__->mk_accessors(qw(
    trace
    go_policy
    serializer_obj
));


# see also $ENV{DBI_GOFER_TRACE} in DBI::Gofer::Execute
sub _init_trace { (split(/=/,$ENV{DBI_GOFER_TRACE}||0))[0] }


sub new {
    my ($class, $args) = @_;
    $args->{trace} ||= $class->_init_trace;
    $args->{serializer_obj} ||= DBI::Gofer::Serializer->new();
    my $self = bless {}, $class;
    $self->$_( $args->{$_} ) for keys %$args;
    $self->trace_msg("$class->new({ @{[ %$args ]} })\n") if $self->trace;
    return $self;
}

{   package DBI::Gofer::Serializer;
    # a very minimal subset of Data::Serializer
    use Storable qw(nfreeze thaw);
    sub new {
        return bless {} => shift;
    }
    sub serializer {
        my $self = shift;
        local $Storable::forgive_me = 1; # for CODE refs etc
        return nfreeze(shift);
    }
    sub deserializer {
        my $self = shift;
        return thaw(shift);
    }
}


my $packet_header_text  = "GoFER1:";
my $packet_header_regex = qr/^GoFER(\d):/;


sub _freeze_data {
    my ($self, $data, $skip_trace) = @_;
    my $frozen = eval {
        $self->_dump("freezing $self->{trace} ".ref($data), $data)
            if !$skip_trace and $self->trace;

        my $header = $packet_header_text;
        my $data = $self->{serializer_obj}->serializer($data);
        $header.$data;
    };
    if ($@) {
        chomp $@;
        die "Error freezing ".ref($data)." object: $@";
    }
    return $frozen;
}
# public aliases used by subclasses
*freeze_request  = \&_freeze_data;
*freeze_response = \&_freeze_data;


sub _thaw_data {
    my ($self, $frozen_data, $skip_trace) = @_;
    my $data;
    eval {
        # check for and extract our gofer header and the info it contains
        $frozen_data =~ s/$packet_header_regex//o
            or die "does not have gofer header\n";
        my ($t_version) = $1;
        $data = $self->{serializer_obj}->deserializer($frozen_data)
            and $data->{_transport}{version} = $t_version;
    };
    if ($@) {
        chomp(my $err = $@);
        # remove extra noise from Storable
        $err =~ s{ at \S+?/Storable.pm \(autosplit into \S+?/Storable/thaw.al\) line \d+(, \S+ line \d+)?}{};
        my $msg = sprintf "Error thawing: %s (data=%s)", $err, DBI::neat($frozen_data,50);
        Carp::cluck("$msg, pid $$ stack trace follows:"); # XXX if $self->trace;
        die $msg;
    }
    $self->_dump("thawing $self->{trace} ".ref($data), $data)
        if !$skip_trace and $self->trace;
    return $data;
}
# public aliases used by subclasses
*thaw_request  = \&_thaw_data;
*thaw_response = \&_thaw_data;


# this should probably live in the request and response classes
# and the tace level passed in
sub _dump {
    my ($self, $label, $data) = @_;
    if ($self->trace >= 2) {
        require Data::Dumper;
        local $Data::Dumper::Indent    = 1;
        local $Data::Dumper::Terse     = 1;
        local $Data::Dumper::Useqq     = 1;
        local $Data::Dumper::Sortkeys  = 1;
        local $Data::Dumper::Quotekeys = 0;
        local $Data::Dumper::Deparse   = 0;
        local $Data::Dumper::Purity    = 0;
        $self->trace_msg("$label: ".Data::Dumper::Dumper($data));
    }
    else {
        my $summary = eval { $data->summary_as_text } || $@ || "no summary available\n";
        $self->trace_msg("$label: $summary");
    }
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

