# NAME

DBD::Gofer::Policy::rush - The 'rush' policy for DBD::Gofer

# SYNOPSIS

    $dbh = DBI->connect("dbi:Gofer:transport=...;policy=rush", ...)

# DESCRIPTION

The `rush` policy tries to make as few round-trips as possible.
It's the opposite end of the policy spectrum to the `pedantic` policy.

Temporary docs: See the source code for list of policies and their defaults.

In a future version the policies and their defaults will be defined in the pod and parsed out at load-time.

# AUTHOR

Tim Bunce, [http://www.tim.bunce.name](http://www.tim.bunce.name)

# LICENCE AND COPYRIGHT

Copyright (c) 2007, Tim Bunce, Ireland. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic).
