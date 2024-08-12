# NAME

DBI::Const::GetInfoType - Data describing GetInfo type codes

# SYNOPSIS

    use DBI::Const::GetInfoType;

# DESCRIPTION

Imports a %GetInfoType hash which maps names for GetInfo Type Codes
into their corresponding numeric values. For example:

    $database_version = $dbh->get_info( $GetInfoType{SQL_DBMS_VER} );

The interface to this module is new and nothing beyond what is
written here is guaranteed.
