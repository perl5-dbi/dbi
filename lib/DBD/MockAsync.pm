package DBD::MockAsync;

use strict;
use warnings;
use DBI qw(:async);
use IO::Handle;
use Scalar::Util qw(weaken);

our $VERSION = '0.01';
our $err = 0;
our $errstr = '';
our $drh;

sub driver {
    return $drh if $drh;
    my ($class, $attr) = @_;
    $class .= '::dr';
    $drh = DBI::_new_drh($class, {
        Name        => 'MockAsync',
        Version     => $VERSION,
        Attribution => 'DBD::MockAsync by LLC-Technologies-Collier',
    });
    return $drh;
}

{
    package DBD::MockAsync::dr;
    our @ISA = qw(DBD::_::dr);
    our $imp_data_size = 0;

    sub connect {
        my ($drh, $dbname, $user, $auth, $attr) = @_;

        pipe(my $r, my $w) or die "Cannot create pipe: $!";

        # Set non-blocking on pipe handles using IO::Handle
        $r->blocking(0);
        $w->blocking(0);

        my ($outer, $dbh) = DBI::_new_dbh($drh, {
            Name             => $dbname,
            mock_pipe_read   => $r,
            mock_pipe_write  => $w,
            mock_buffer      => '',
            mock_rows        => [],
        });

        $dbh->STORE('AutoCommit', 1);
        $dbh->STORE('Active', 1);

        return $outer;
    }

    sub data_sources {
        return ('dbi:MockAsync:');
    }
}

{
    package DBD::MockAsync::db;
    our @ISA = qw(DBD::_::db);
    our $imp_data_size = 0;

    sub STORE {
        my ($dbh, $attr, $val) = @_;
        if ($attr eq 'AutoCommit') {
            $val = ($val) ? -901 : -900;
        }
        return $dbh->SUPER::STORE($attr, $val);
    }

    sub prepare {
        my ($dbh, $statement, $attr) = @_;

        my ($outer, $sth) = DBI::_new_sth($dbh, {
            Statement => $statement,
        });

        $sth->STORE('Active', 1);
        return $outer;
    }

    sub async_read_ready {
        my ($h) = @_;
        my $inner = tied(%$h) || $h;
        my $r = $inner->{mock_pipe_read};
        return 0 unless $r;

        my $buf = '';
        my $bytes = sysread($r, $buf, 1024);

        if (defined $bytes && $bytes > 0) {
            $inner->{mock_buffer} .= $buf;

            # If line received, process frames
            if ($inner->{mock_buffer} =~ s/^(.*?)\n//) {
                my $line = $1;
                push @{ $inner->{mock_rows} }, [ split(/,/, $line) ];

                # Clear AsyncWantRead flag
                $h->STORE('AsyncWantRead', 0);

                # Notify watcher on_remove if set
                my $watcher = $h->{AsyncWatcher};
                if ($watcher && ref($watcher) eq 'HASH' && $watcher->{on_remove}) {
                    $watcher->{on_remove}->(fileno($r));
                }
                return 1;
            }
            return 1;
        }
        return 0;
    }

    sub async_write_ready {
        my ($h) = @_;
        $h->STORE('AsyncWantWrite', 0);
        return 1;
    }

    sub commit {
        my ($h) = @_;
        return 1;
    }

    sub rollback {
        my ($h) = @_;
        return 1;
    }
}

{
    package DBD::MockAsync::st;
    use DBI qw(:async);
    our @ISA = qw(DBD::_::st);
    our $imp_data_size = 0;

    sub execute {
        my ($sth, @args) = @_;
        my $dbh = $sth->{Database};
        my $inner_dbh = tied(%$dbh) || $dbh;
        my $r = $inner_dbh->{mock_pipe_read};

        if ($dbh->{Async}) {
            $dbh->STORE('AsyncWantRead', 1);

            # Trigger watcher on_add if configured
            my $watcher = $dbh->{AsyncWatcher};
            if ($watcher && ref($watcher) eq 'HASH' && $watcher->{on_add}) {
                $watcher->{on_add}->(fileno($r), 'r');
            }

            # Return WOULDBLOCK yield
            $sth->set_err(DBI_ASYNC_WOULDBLOCK, "Asynchronous Would Block", "HYAS0");
            return "0E0";
        }

        return 1;
    }

    sub fetch_async_row {
        my ($sth) = @_;
        my $dbh = $sth->{Database};
        my $inner_dbh = tied(%$dbh) || $dbh;

        if ($dbh->{AsyncWantRead}) {
            $sth->set_err(DBI_ASYNC_WOULDBLOCK, "Asynchronous Would Block", "HYAS0");
            return DBI_ASYNC_WOULDBLOCK;
        }

        if (@{ $inner_dbh->{mock_rows} }) {
            return shift @{ $inner_dbh->{mock_rows} };
        }

        return undef;
    }

    sub fetchrow_arrayref {
        my ($sth) = @_;
        return $sth->fetch_async_row();
    }
    *fetch = \&fetchrow_arrayref;
}

1;
