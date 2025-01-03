# NAME

DBD::Gofer::Transport::Base - base class for DBD::Gofer client transports

# SYNOPSIS

    my $remote_dsn = "..."
    DBI->connect("dbi:Gofer:transport=...;url=...;timeout=...;retry_limit=...;dsn=$remote_dsn",...)

or, enable by setting the DBI\_AUTOPROXY environment variable:

    export DBI_AUTOPROXY='dbi:Gofer:transport=...;url=...'

which will force _all_ DBI connections to be made via that Gofer server.

# DESCRIPTION

This is the base class for all DBD::Gofer client transports.

# ATTRIBUTES

Gofer transport attributes can be specified either in the attributes parameter
of the connect() method call, or in the DSN string. When used in the DSN
string, attribute names don't have the `go_` prefix.

## go\_dsn

The full DBI DSN that the Gofer server should connect to on your behalf.

When used in the DSN it must be the last element in the DSN string.

## go\_timeout

A time limit for sending a request and receiving a response. Some drivers may
implement sending and receiving as separate steps, in which case (currently)
the timeout applies to each separately.

If a request needs to be resent then the timeout is restarted for each sending
of a request and receiving of a response.

## go\_retry\_limit

The maximum number of times an request may be retried. The default is 2.

## go\_retry\_hook

This subroutine reference is called, if defined, for each response received where $response->err is true.

The subroutine is pass three parameters: the request object, the response object, and the transport object.

If it returns an undefined value then the default retry behaviour is used. See ["RETRY ON ERROR"](#retry-on-error) below.

If it returns a defined but false value then the request is not resent.

If it returns true value then the request is resent, so long as the number of retries does not exceed `go_retry_limit`.

# RETRY ON ERROR

The default retry on error behaviour is:

    - Retry if the error was due to DBI_GOFER_RANDOM. See L<DBI::Gofer::Execute>.

    - Retry if $request->is_idempotent returns true. See L<DBI::Gofer::Request>.

A retry won't be allowed if the number of previous retries has reached `go_retry_limit`.

# TRACING

Tracing of gofer requests and responses can be enabled by setting the
`DBD_GOFER_TRACE` environment variable. A value of 1 gives a reasonably
compact summary of each request and response. A value of 2 or more gives a
detailed, and voluminous, dump.

The trace is written using DBI->trace\_msg() and so is written to the default
DBI trace output, which is usually STDERR.

# METHODS

_This section is currently far from complete._

## response\_retry\_preference

    $retry = $transport->response_retry_preference($request, $response);

The response\_retry\_preference is called by DBD::Gofer when considering if a
request should be retried after an error.

Returns true (would like to retry), false (must not retry), undef (no preference).

If a true value is returned in the form of a CODE ref then, if DBD::Gofer does
decide to retry the request, it calls the code ref passing $retry\_count, $retry\_limit.
Can be used for logging and/or to implement exponential backoff behaviour.
Currently the called code must return using `return;` to allow for future extensions.

# AUTHOR

Tim Bunce, [http://www.tim.bunce.name](http://www.tim.bunce.name)

# LICENCE AND COPYRIGHT

Copyright (c) 2007-2008, Tim Bunce, Ireland. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic).

# SEE ALSO

[DBD::Gofer](https://metacpan.org/pod/DBD%3A%3AGofer), [DBI::Gofer::Request](https://metacpan.org/pod/DBI%3A%3AGofer%3A%3ARequest), [DBI::Gofer::Response](https://metacpan.org/pod/DBI%3A%3AGofer%3A%3AResponse), [DBI::Gofer::Execute](https://metacpan.org/pod/DBI%3A%3AGofer%3A%3AExecute).

and some example transports:

[DBD::Gofer::Transport::stream](https://metacpan.org/pod/DBD%3A%3AGofer%3A%3ATransport%3A%3Astream)

[DBD::Gofer::Transport::http](https://metacpan.org/pod/DBD%3A%3AGofer%3A%3ATransport%3A%3Ahttp)

[DBI::Gofer::Transport::mod\_perl](https://metacpan.org/pod/DBI%3A%3AGofer%3A%3ATransport%3A%3Amod_perl)
