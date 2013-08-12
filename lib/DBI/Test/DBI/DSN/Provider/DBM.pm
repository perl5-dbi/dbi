package DBI::Test::DBI::DSN::Provider::DBM;

use strict;
use warnings;

use parent qw(DBI::Test::DSN::Provider::Dir);

my %have_stuff;

sub dsn_conf
{
    my ( $self, $test_case_ns ) = @_;

    my ( %variants, %mldbm_types, @dbm_types );
    if ( $test_case_ns->can("requires_extended") and $test_case_ns->requires_extended )
    {
        if ( eval { require 'MLDBM.pm'; } )
        {
            $mldbm_types{''} = {};    # allow an empty variant
            $mldbm_types{d} = { dbm_mldbm => 'Data::Dumper' };    # both in CORE
            $mldbm_types{s} = { dbm_mldbm => 'Storable' };        # both in CORE
            $mldbm_types{f} = { dbm_mldbm => 'FreezeThaw' } if eval { require 'FreezeThaw.pm' };
            $mldbm_types{y} = { dbm_mldbm => 'YAML' } if eval { require MLDBM::Serializer::YAML; };
            $mldbm_types{j} = { dbm_mldbm => 'JSON' } if eval { require MLDBM::Serializer::JSON; };
        }

        # Potential DBM modules in preference order (SDBM_File first)
        # skip NDBM and ODBM as they don't support EXISTS
        my @dbms     = qw(SDBM_File GDBM_File DB_File BerkeleyDB);    #(NDBM_File ODBM_File);
        my @use_dbms = @ARGV;
        if ( !@use_dbms && $ENV{DBD_DBM_TEST_BACKENDS} )
        {
            @use_dbms = split ' ', $ENV{DBD_DBM_TEST_BACKENDS};
        }
        if ( lc "@use_dbms" eq "all" )
        {
            # test with as many of the major DBM types as are available
            @dbm_types = grep {
                eval { local $^W; require "$_.pm" }
            } @dbms;
        }
        elsif (@use_dbms)
        {
            @dbm_types = @use_dbms;
        }
        else
        {
            # we only test SDBM_File by default to avoid tripping up
            # on any broken DBM's that may be installed in odd places.
            # It's only DBD::DBM we're trying to test here.
            # (However, if SDBM_File is not available, then use another.)
            for my $dbm (@dbms)
            {
                if ( eval { local $^W; require "$dbm.pm" } )
                {
                    @dbm_types = ($dbm);
                    last;
                }
            }
        }

        scalar( keys %mldbm_types ) and $variants{variants}->{mldbm} = \%mldbm_types;
        scalar(@dbm_types)
          and %{ $variants{variants}->{type} } =
          map { lc( substr( $_, 0, 1 ) ) => { dbm_type => $_ } } @dbm_types;
    }

    "DBM" => {
               category   => "driver",
               cat_abbrev => "d",
               abbrev     => "d",
               driver     => "dbi:DBM:",
               name       => "DSN for DBD::DBM",
               %variants,
             };
}

1;
