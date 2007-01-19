package DBI::Forward::Request;

use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(
    connect_args
    dbh_method_name
    dbh_method_args
    dbh_wantarray
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
    my ($self, $method, $args_ref, $wantarray) = @_;
    $self->reset;
    $self->dbh_method_name($method);
    $self->dbh_method_args($args_ref);
    $self->dbh_wantarray($wantarray);
}

1;
