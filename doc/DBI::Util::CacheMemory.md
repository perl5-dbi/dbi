# NAME

DBI::Util::CacheMemory - a very fast but very minimal subset of Cache::Memory

# DESCRIPTION

Like Cache::Memory (part of the Cache distribution) but doesn't support any fancy features.

This module aims to be a very fast compatible strict sub-set for simple cases,
such as basic client-side caching for DBD::Gofer.

Like Cache::Memory, and other caches in the Cache and Cache::Cache
distributions, the data will remain in the cache until cleared, it expires,
or the process dies. The cache object simply going out of scope will _not_
destroy the data.

# METHODS WITH CHANGES

## new

All options except `namespace` are ignored.

## set

Doesn't support expiry.

## purge

Same as clear() - deletes everything in the namespace.

# METHODS WITHOUT CHANGES

- clear
- count
- exists
- remove

# UNSUPPORTED METHODS

If it's not listed above, it's not supported.
