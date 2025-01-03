# NAME

DBD::Gofer::Policy::classic - The 'classic' policy for DBD::Gofer

# SYNOPSIS

    $dbh = DBI->connect("dbi:Gofer:transport=...;policy=classic", ...)

The `classic` policy is the default DBD::Gofer policy, so need not be included in the DSN.

# DESCRIPTION

Temporary docs: See the source code for list of policies and their defaults.

In a future version the policies and their defaults will be defined in the pod and parsed out at load-time.

# AUTHOR

Tim Bunce, [http://www.tim.bunce.name](http://www.tim.bunce.name)

# LICENCE AND COPYRIGHT

Copyright (c) 2007, Tim Bunce, Ireland. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic).
