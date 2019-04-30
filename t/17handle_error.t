#!perl -w

use strict;
use warnings;

use DBI;
use Test::More;

my $skip_error;
my $skip_warn;
my $handled_errstr;
sub error_sub {
    my ($errstr, $dbh, $ret) = @_;
    $handled_errstr = $errstr;
    $handled_errstr =~ s/.* set_err (?:failed|warning): //;
    return $ret unless ($skip_error and $errstr =~ / set_err failed: /) or ($skip_warn and $errstr =~ / set_err warning:/);
    $dbh->set_err(undef, undef);
    return 1;
}

my $dbh = DBI->connect('dbi:ExampleP:.', undef, undef, { PrintError => 0, RaiseError => 0, PrintWarn => 0, RaiseWarn => 0, HandleError => \&error_sub });

sub clear_err {
    $dbh->set_err(undef, undef);
    $handled_errstr = undef;
}

###

ok eval { $dbh->set_err('', 'string 1'); 1 } or diag($@);
is $dbh->err, '';
is $dbh->errstr, 'string 1';
is $handled_errstr, undef;
clear_err;

ok eval { $dbh->set_err(0, 'string 2'); 1 } or diag($@);
is $dbh->err, 0;
is $dbh->errstr, 'string 2';
is $handled_errstr, undef;
clear_err;

ok eval { $dbh->set_err(1, 'string 3'); 1 } or diag($@);
is $dbh->err, 1;
is $dbh->errstr, 'string 3';
is $handled_errstr, 'string 3';
clear_err;

###

$dbh->{RaiseError} = 1;

ok eval { $dbh->set_err('', 'string 4'); 1 } or diag($@);
is $dbh->err, '';
is $dbh->errstr, 'string 4';
is $handled_errstr, undef;
clear_err;

ok eval { $dbh->set_err(0, 'string 5'); 1 } or diag($@);
is $dbh->err, 0;
is $dbh->errstr, 'string 5';
is $handled_errstr, undef;
clear_err;

ok !eval { $dbh->set_err(1, 'string 6'); 1 };
is $dbh->err, 1;
is $dbh->errstr, 'string 6';
is $handled_errstr, 'string 6';
clear_err;

$dbh->{RaiseError} = 0;

###

$dbh->{RaiseWarn} = 1;

ok eval { $dbh->set_err('', 'string 7'); 1 } or diag($@);
is $dbh->err, '';
is $dbh->errstr, 'string 7';
is $handled_errstr, undef;
clear_err;

ok !eval { $dbh->set_err(0, 'string 8'); 1 };
is $dbh->err, 0;
is $dbh->errstr, 'string 8';
is $handled_errstr, 'string 8';
clear_err;

ok eval { $dbh->set_err(1, 'string 9'); 1 } or diag($@);
is $dbh->err, 1;
is $dbh->errstr, 'string 9';
is $handled_errstr, 'string 9';
clear_err;

$dbh->{RaiseWarn} = 0;

###

$dbh->{RaiseError} = 1;
$dbh->{RaiseWarn} = 1;

ok eval { $dbh->set_err('', 'string 10'); 1 } or diag($@);
is $dbh->err, '';
is $dbh->errstr, 'string 10';
is $handled_errstr, undef;
clear_err;

ok !eval { $dbh->set_err(0, 'string 11'); 1 };
is $dbh->err, 0;
is $dbh->errstr, 'string 11';
is $handled_errstr, 'string 11';
clear_err;

ok !eval { $dbh->set_err(1, 'string 12'); 1 };
is $dbh->err, 1;
is $dbh->errstr, 'string 12';
is $handled_errstr, 'string 12';
clear_err;

$dbh->{RaiseError} = 0;
$dbh->{RaiseWarn} = 0;

###

$dbh->{RaiseError} = 1;
$skip_error = 1;

ok eval { $dbh->set_err('', 'string 13'); 1 } or diag($@);
is $dbh->err, '';
is $dbh->errstr, 'string 13';
is $handled_errstr, undef;
clear_err;

ok eval { $dbh->set_err(0, 'string 14'); 1 } or diag($@);
is $dbh->err, 0;
is $dbh->errstr, 'string 14';
is $handled_errstr, undef;
clear_err;

ok eval { $dbh->set_err(1, 'string 15'); 1 } or diag($@);
is $dbh->err, undef;
is $dbh->errstr, undef;
is $handled_errstr, 'string 15';
clear_err;

$dbh->{RaiseError} = 0;
$skip_error = 0;

###

$dbh->{RaiseWarn} = 1;
$skip_warn = 1;

ok eval { $dbh->set_err('', 'string 16'); 1 } or diag($@);
is $dbh->err, '';
is $dbh->errstr, 'string 16';
is $handled_errstr, undef;
clear_err;

ok eval { $dbh->set_err(0, 'string 17'); 1 } or diag($@);
is $dbh->err, undef;
is $dbh->errstr, undef;
is $handled_errstr, 'string 17';
clear_err;

ok eval { $dbh->set_err(1, 'string 18'); 1 } or diag($@);
is $dbh->err, 1;
is $dbh->errstr, 'string 18';
is $handled_errstr, 'string 18';
clear_err;

$dbh->{RaiseWarn} = 0;
$skip_error = 0;

###

$dbh->{RaiseError} = 1;
$dbh->{RaiseWarn} = 1;
$skip_error = 1;
$skip_warn = 1;

ok eval { $dbh->set_err('', 'string 19'); 1 } or diag($@);
is $dbh->err, '';
is $dbh->errstr, 'string 19';
is $handled_errstr, undef;
clear_err;

ok eval { $dbh->set_err(0, 'string 20'); 1 } or diag($@);
is $dbh->err, undef;
is $dbh->errstr, undef;
is $handled_errstr, 'string 20';
clear_err;

ok eval { $dbh->set_err(1, 'string 21'); 1 } or diag($@);
is $dbh->err, undef;
is $dbh->errstr, undef;
is $handled_errstr, 'string 21';
clear_err;

$dbh->{RaiseError} = 0;
$dbh->{RaiseWarn} = 0;
$skip_error = 0;

###

done_testing;
