#!/usr/bin/perl

    use strict;
    use warnings;
    use DBI;
    use Devel::Leak;
    use Test::More;
    
    # some dsn configuration
    my %dsn = (
        sqlite => [ 'dbi:SQLite:dbname=test.sql', '', '' ],
        #mysql  => [ 'dbi:mysql:test',             '', '' ],
        #csv    => [ 'dbi:CSV:',                   '', '' ],
    );
    
    # generic SQL
    my %SQL = (
        drop   => 'DROP TABLE IF EXISTS tok',
        create => 'CREATE TABLE tok (kuk INT, zat INT, sob TEXT)',
        insert => 'INSERT INTO tok (kuk, zat, sob) VALUES (?,?,?)',
        select => 'SELECT kuk, zat, sob FROM tok',
    );
    
    my @tests = (
        q{my $sanity = 1;},    # simple sanity test (eval "" doesn't leak)
        q{my $s = $dbh->trace(0) },
        q{my $s = $dbh->prepare($sql) },
        q{my $s = $dbh->prepare($sql); $s->execute(); },
        q{my $s = $dbh->prepare( $sql ); $s->execute(); 1 while $s->fetchrow_arrayref(); $s->finish;},
        q{my $s = $dbh->prepare_cached( $sql ); $s->execute(); 1 while $s->fetchrow_arrayref(); $s->finish;},
        q{my $c = $dbh->selectcol_arrayref( $sql, { Column => [1] } )},
        q{my @a = $dbh->selectrow_array( $sql )},
        q{my $a = $dbh->selectrow_arrayref( $sql )},
    );
    
    # plan
    plan tests => @tests * keys %dsn;
    
    my $empty = "";
    for my $dbd ( sort keys %dsn ) {
    
      SKIP: {
    
            # connect to the test db
            my $dbh =
              eval { DBI->connect( @{ $dsn{$dbd} }, { RaiseError => 1 } ); };
    
            skip "Connection to $dbd failed: $@", scalar @tests if !$dbh;
    
            # initialize the table
            $dbh->do( $SQL{drop} );
            $dbh->do( $SQL{create} );
    
            # fill in some data
            my $sth;
            $sth = $dbh->prepare( $SQL{insert} );
            $sth->execute( $_, 100 - $_, 'x' x $_ ) for 1 .. 30;
    
            # test each command
            for my $cmd (@tests) {
    
                # get the SQL statement
                my $sql = $SQL{select};
                $cmd = $cmd.q{; $dbh->{Statement}="";};
    
                # run once, in case some internal structures get initialized
                eval $cmd;
    
                # now look for leakage
                my $c1 = Devel::Leak::NoteSV( my $h );
                {
                    eval $cmd;
                }
                my $c2 = Devel::Leak::CheckSV($h);
                diag $@ if $@;
    
                my $leak = $c2 - $c1;
                is( $leak, 0, sprintf "\tleak=%2d for %-8s%s", $leak, $dbd, $cmd );
            }
            warn "##########################################################################\n";
    
        }
    }
