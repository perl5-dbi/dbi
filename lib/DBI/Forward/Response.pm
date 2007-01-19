package DBI::Forward::Response;

use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(
    rv
    err
    errstr
    state
    last_insert_id
    sth_resultsets
));

1;
