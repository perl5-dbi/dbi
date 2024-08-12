# NAME

DBD::Gofer::Transport::null - DBD::Gofer client transport for testing

# SYNOPSIS

    my $original_dsn = "..."
    DBI->connect("dbi:Gofer:transport=null;dsn=$original_dsn",...)

or, enable by setting the DBI\_AUTOPROXY environment variable:

    export DBI_AUTOPROXY="dbi:Gofer:transport=null"

# DESCRIPTION

Connect via DBD::Gofer but execute the requests within the same process.

This is a quick and simple way to test applications for compatibility with the
(few) restrictions that DBD::Gofer imposes.

It also provides a simple, portable way for the DBI test suite to be used to
test DBD::Gofer on all platforms with no setup.

Also, by measuring the difference in performance between normal connections and
connections via `dbi:Gofer:transport=null` the basic cost of using DBD::Gofer
can be measured. Furthermore, the additional cost of more advanced transports can be
isolated by comparing their performance with the null transport.

The `t/85gofer.t` script in the DBI distribution includes a comparative benchmark.

# AUTHOR

Tim Bunce, [http://www.tim.bunce.name](http://www.tim.bunce.name)

# LICENCE AND COPYRIGHT

Copyright (c) 2007, Tim Bunce, Ireland. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic).

# SEE ALSO

[DBD::Gofer::Transport::Base](https://metacpan.org/pod/DBD%3A%3AGofer%3A%3ATransport%3A%3ABase)

[DBD::Gofer](https://metacpan.org/pod/DBD%3A%3AGofer)
