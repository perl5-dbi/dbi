package DBD::Forward::Transport::Base;

use strict;
use warnings;

use Storable qw(freeze thaw);

use base qw(Class::Accessor::Fast);

our $debug = $ENV{DBD_FORWARD_DEBUG} || 0;


__PACKAGE__->mk_accessors(qw(
    fwd_dsn
));


sub freeze_data {
    my ($self, $data) = @_;
    $self->_dump(ref($data), $data) if $debug;
    return freeze($data);
}   

sub thaw_data {
    my ($self, $frozen_data) = @_;
    my $data = thaw($frozen_data);
    $self->_dump(ref($data), $data) if $debug;
    return $data;
}


sub _dump {
    my ($self, $label, $data) = @_;
    require Data::Dumper;
    warn "$label=".Dumper($data);

}

1;
