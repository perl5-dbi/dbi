# NAME

DBI::Gofer::Serializer::Storable - Gofer serialization using Storable

# SYNOPSIS

    $serializer = DBI::Gofer::Serializer::Storable->new();

    $string = $serializer->serialize( $data );
    ($string, $deserializer_class) = $serializer->serialize( $data );

    $data = $serializer->deserialize( $string );

# DESCRIPTION

Uses Storable::nfreeze() to serialize and Storable::thaw() to deserialize.

The serialize() method sets local $Storable::forgive\_me = 1; so it doesn't
croak if it encounters any data types that can't be serialized, such as code refs.

See also [DBI::Gofer::Serializer::Base](https://metacpan.org/pod/DBI%3A%3AGofer%3A%3ASerializer%3A%3ABase).
