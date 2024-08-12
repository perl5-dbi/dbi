# NAME

DBI::Gofer::Serializer::DataDumper - Gofer serialization using DataDumper

# SYNOPSIS

    $serializer = DBI::Gofer::Serializer::DataDumper->new();

    $string = $serializer->serialize( $data );

# DESCRIPTION

Uses DataDumper to serialize. Deserialization is not supported.
The output of this class is only meant for human consumption.

See also [DBI::Gofer::Serializer::Base](https://metacpan.org/pod/DBI%3A%3AGofer%3A%3ASerializer%3A%3ABase).
