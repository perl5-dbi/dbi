#!/usr/bin/perl

use 5.012001;
use warnings;
use Test::More;

BEGIN { $ENV{AUTHOR_TESTING} = 1; }
eval "use Test::Kwalitee qw( kwalitee_ok );";
if ($@) {
    diag $@ =~ s{\s+at\s+\S+\s+line\s+\d.*\z}{}rs;
    plan skip_all => "1..0 # Test::Kwalitee required for this test\n";
    }

kwalitee_ok (qw(
    -has_meta_yml
    -metayml_conforms_spec_current
    -metayml_conforms_to_known_spec
    -metayml_declares_perl_version
    -metayml_has_license
    -metayml_has_provides
    -metayml_is_parsable
    -no_symlinks
    ));

my @experimental = qw(
     no_stdin_for_prompting
     prereq_matches_use
     has_test_pod
     has_test_pod_coverage
     use_warnings

     build_prereq_matches_use
     easily_repackageable
     easily_repackageable_by_debian
     easily_repackageable_by_fedora
     fits_fedora_license
     has_license_in_source_file
     has_version_in_each_file
     uses_test_nowarnings
     );

done_testing ();
