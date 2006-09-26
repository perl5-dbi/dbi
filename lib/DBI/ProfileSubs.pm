package DBI::ProfileSubs;

=head1 NAME

DBI::ProfileSubs - Subroutines for dynamic profile Path

=head1 SYNOPSIS

  DBI_PROFILE='& prog.pl

This is new and still experimental.

=cut

use strict;
use warnings;


# would be good to refactor these regex into separate subs or find some other
# way to compose them in various combinations into multiple subs

sub norm_std_n3 {
    # my ($h, $method_name) = @_;
    local $_ = $_;

    s/\b\d+\b/<N>/g;             # 42 -> <N>
    s/\b0x[0-9A-Fa-f]+\b/<N>/g;  # 0xFE -> <N>

    s/'.*?'/'<S>'/g;             # single quoted strings (doesn't handle escapes)
    s/".*?"/"<S>"/g;             # double quoted strings (doesn't handle escapes)

    # convert names like log20001231 into log<N>
    s/([a-z_]+)(\d{3,})\b/${1}<N>/ig;

    # abbreviate massive "in (...)" statements and similar
    s!((\s*<[NS]>\s*,\s*){100,})!sprintf("$2,<repeated %d times>",length($1)/2)!eg;

    return $_;
}

1;
