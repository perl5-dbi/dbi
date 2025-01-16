# NAME

DBD::Mem - a DBI driver for Mem & MLMem files

# SYNOPSIS

    use DBI;
    $dbh = DBI->connect('dbi:Mem:', undef, undef, {});
    $dbh = DBI->connect('dbi:Mem:', undef, undef, {RaiseError => 1});

    # or
    $dbh = DBI->connect('dbi:Mem:');
    $dbh = DBI->connect('DBI:Mem(RaiseError=1):');

and other variations on connect() as shown in the [DBI](https://metacpan.org/pod/DBI) docs and
<DBI::DBD::SqlEngine metadata|DBI::DBD::SqlEngine/Metadata>.

Use standard DBI prepare, execute, fetch, placeholders, etc.

# DESCRIPTION

DBD::Mem is a database management system that works right out of the box.
If you have a standard installation of Perl and DBI you can begin creating,
accessing, and modifying simple database tables without any further modules.
You can add other modules (e.g., SQL::Statement) for improved functionality.

DBD::Mem doesn't store any data persistently - all data has the lifetime of
the instantiated `$dbh`. The main reason to use DBD::Mem is to use extended
features of [SQL::Statement](https://metacpan.org/pod/SQL%3A%3AStatement) where temporary tables are required. One can
use DBD::Mem to simulate `VIEWS` or sub-queries.

Bundling `DBD::Mem` with [DBI](https://metacpan.org/pod/DBI) will allow us further compatibility checks
of [DBI::DBD::SqlEngine](https://metacpan.org/pod/DBI%3A%3ADBD%3A%3ASqlEngine) beyond the capabilities of [DBD::File](https://metacpan.org/pod/DBD%3A%3AFile) and
[DBD::DBM](https://metacpan.org/pod/DBD%3A%3ADBM). This will ensure DBI provided basis for drivers like
[DBD::AnyData2](https://metacpan.org/pod/DBD%3A%3AAnyData2) or [DBD::Amazon](https://metacpan.org/pod/DBD%3A%3AAmazon) are better prepared and tested for
not-file based backends.

## Metadata

There're no new meta data introduced by `DBD::Mem`. See
["Metadata" in DBI::DBD::SqlEngine](https://metacpan.org/pod/DBI%3A%3ADBD%3A%3ASqlEngine#Metadata) for full description.

# GETTING HELP, MAKING SUGGESTIONS, AND REPORTING BUGS

If you need help installing or using DBD::Mem, please write to the DBI
users mailing list at [mailto:dbi-users@perl.org](mailto:dbi-users@perl.org) or to the
comp.lang.perl.modules newsgroup on usenet.  I cannot always answer
every question quickly but there are many on the mailing list or in
the newsgroup who can.

DBD developers for DBD's which rely on DBI::DBD::SqlEngine or DBD::Mem or
use one of them as an example are suggested to join the DBI developers
mailing list at [mailto:dbi-dev@perl.org](mailto:dbi-dev@perl.org) and strongly encouraged to join our
IRC channel at [irc://irc.perl.org/dbi](irc://irc.perl.org/dbi).

If you have suggestions, ideas for improvements, or bugs to report, please
report a bug as described in DBI. Do not mail any of the authors directly,
you might not get an answer.

When reporting bugs, please send the output of `$dbh->mem_versions($table)`
for a table that exhibits the bug and as small a sample as you can make of
the code that produces the bug.  And of course, patches are welcome, too
:-).

If you need enhancements quickly, you can get commercial support as
described at [http://dbi.perl.org/support/](http://dbi.perl.org/support/) or you can contact Jens Rehsack
at rehsack@cpan.org for commercial support.

# AUTHOR AND COPYRIGHT

This module is written by Jens Rehsack < rehsack AT cpan.org >.

    Copyright (c) 2016- by Jens Rehsack, all rights reserved.

You may freely distribute and/or modify this module under the terms of
either the GNU General Public License (GPL) or the Artistic License, as
specified in the Perl README file.

# SEE ALSO

[DBI](https://metacpan.org/pod/DBI) for the Database interface of the Perl Programming Language.

[SQL::Statement](https://metacpan.org/pod/SQL%3A%3AStatement) and [DBI::SQL::Nano](https://metacpan.org/pod/DBI%3A%3ASQL%3A%3ANano) for the available SQL engines.

[SQL::Statement::RAM](https://metacpan.org/pod/SQL%3A%3AStatement%3A%3ARAM) where the implementation is shamelessly stolen from
to allow DBI bundled Pure-Perl drivers increase the test coverage.

[DBD::SQLite](https://metacpan.org/pod/DBD%3A%3ASQLite) using `dbname=:memory:` for an incredible fast in-memory database engine.
