# NAME

DBI::W32ODBC - An experimental DBI emulation layer for Win32::ODBC

# SYNOPSIS

    use DBI::W32ODBC;

    # apart from the line above everything is just the same as with
    # the real DBI when using a basic driver with few features.

# DESCRIPTION

This is an experimental pure perl DBI emulation layer for Win32::ODBC

If you can improve this code I'd be interested in hearing about it. If
you are having trouble using it please respect the fact that it's very
experimental. Ideally fix it yourself and send me the details.

## Some Things Not Yet Implemented

        Most attributes including PrintError & RaiseError.
        type_info and table_info

Volunteers welcome!
