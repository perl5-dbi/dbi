package DBI::Forward::Transport::Base;

use strict;
use warnings;

use Storable qw(freeze thaw);

use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(
    fwd_dsn
));

sub execute {
    my ($self, $request) = @_;
    die ref($self)." has not implemented a transport method";
}


1;
