package DBI::Test::DBI::Case;

use strict;
use warnings;

use parent qw(DBI::Test::Case);

use Carp qw(carp);

use DBI::Mock ();

# default filter applies to PROVIDED_DBDS - modify if we want test more
# sub filter_drivers

# should be enabled by test, if wanted
# sub requires_extended { 0 }

sub supported_variant
{
    my ( $self, $test_case, $cfg_pfx, $test_confs, $dsn_pfx, $dsn_cred, $options ) = @_;

    # don't re-run tests for DBI::Mock
    $self->is_test_for_mocked($test_confs) and return;

    return 1;
}

1;
