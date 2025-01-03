# NAME

DBD::Gofer::Transport::stream - DBD::Gofer transport for stdio streaming

# SYNOPSIS

    DBI->connect('dbi:Gofer:transport=stream;url=ssh:username@host.example.com;dsn=dbi:...',...)

or, enable by setting the DBI\_AUTOPROXY environment variable:

    export DBI_AUTOPROXY='dbi:Gofer:transport=stream;url=ssh:username@host.example.com'

# DESCRIPTION

Without the `url=` parameter it launches a subprocess as

    perl -MDBI::Gofer::Transport::stream -e run_stdio_hex

and feeds requests into it and reads responses from it. But that's not very useful.

With a `url=ssh:username@host.example.com` parameter it uses ssh to launch the subprocess
on a remote system. That's much more useful!

It gives you secure remote access to DBI databases on any system you can login to.
Using ssh also gives you optional compression and many other features (see the
ssh manual for how to configure that and many other options via ~/.ssh/config file).

The actual command invoked is something like:

    ssh -xq ssh:username@host.example.com bash -c $setup $run

where $run is the command shown above, and $command is

    . .bash_profile 2>/dev/null || . .bash_login 2>/dev/null || . .profile 2>/dev/null; exec "$@"

which is trying (in a limited and fairly unportable way) to setup the environment
(PATH, PERL5LIB etc) as it would be if you had logged in to that system.

The "`perl`" used in the command will default to the value of $^X when not using ssh.
On most systems that's the full path to the perl that's currently executing.

# PERSISTENCE

Currently gofer stream connections persist (remain connected) after all
database handles have been disconnected. This makes later connections in the
same process very fast.

Currently up to 5 different gofer stream connections (based on url) can
persist.  If more than 5 are in the cache when a new connection is made then
the cache is cleared before adding the new connection. Simple but effective.

# TO DO

Document go\_perl attribute

Automatically reconnect (within reason) if there's a transport error.

Decide on default for persistent connection - on or off? limits? ttl?

# AUTHOR

Tim Bunce, [http://www.tim.bunce.name](http://www.tim.bunce.name)

# LICENCE AND COPYRIGHT

Copyright (c) 2007, Tim Bunce, Ireland. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic).

# SEE ALSO

[DBD::Gofer::Transport::Base](https://metacpan.org/pod/DBD%3A%3AGofer%3A%3ATransport%3A%3ABase)

[DBD::Gofer](https://metacpan.org/pod/DBD%3A%3AGofer)
