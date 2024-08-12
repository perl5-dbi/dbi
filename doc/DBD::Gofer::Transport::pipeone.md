# NAME

DBD::Gofer::Transport::pipeone - DBD::Gofer client transport for testing

# SYNOPSIS

    $original_dsn = "...";
    DBI->connect("dbi:Gofer:transport=pipeone;dsn=$original_dsn",...)

or, enable by setting the DBI\_AUTOPROXY environment variable:

    export DBI_AUTOPROXY="dbi:Gofer:transport=pipeone"

# DESCRIPTION

Connect via DBD::Gofer and execute each request by starting executing a subprocess.

This is, as you might imagine, spectacularly inefficient!

It's only intended for testing. Specifically it demonstrates that the server
side is completely stateless.

It also provides a base class for the much more useful [DBD::Gofer::Transport::stream](https://metacpan.org/pod/DBD%3A%3AGofer%3A%3ATransport%3A%3Astream)
transport.

# AUTHOR

Tim Bunce, [http://www.tim.bunce.name](http://www.tim.bunce.name)

# LICENCE AND COPYRIGHT

Copyright (c) 2007, Tim Bunce, Ireland. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic).

# SEE ALSO

[DBD::Gofer::Transport::Base](https://metacpan.org/pod/DBD%3A%3AGofer%3A%3ATransport%3A%3ABase)

[DBD::Gofer](https://metacpan.org/pod/DBD%3A%3AGofer)
