# NAME

DBI::Gofer::Serializer::Base - base class for Gofer serialization

# SYNOPSIS

    $serializer = $serializer_class->new();

    $string = $serializer->serialize( $data );
    ($string, $deserializer_class) = $serializer->serialize( $data );

    $data = $serializer->deserialize( $string );

# DESCRIPTION

DBI::Gofer::Serializer::\* classes implement a very minimal subset of the [Data::Serializer](https://metacpan.org/pod/Data%3A%3ASerializer) API.

Gofer serializers are expected to be very fast and are not required to deal
with anything other than non-blessed references to arrays and hashes, and plain scalars.
