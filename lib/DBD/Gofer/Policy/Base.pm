package DBD::Gofer::Policy::Base;

#   $Id$
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

use strict;
use warnings;
use Carp;

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);
our $AUTOLOAD;

my %policy_defaults = (
    skip_connect_check => 0,
    skip_prepare_check => 0,
    skip_ping => 0,
    dbh_attribute_update => 'every',
    dbh_attribute_list => ['*'],
);

my $base_policy_file = $INC{"DBD/Gofer/Policy/Base.pm"};

__PACKAGE__->create_default_policy_subs(\%policy_defaults);

sub create_default_policy_subs {
    my ($class, $policy_defaults) = @_;

    while ( my ($policy_name, $policy_default) = each %$policy_defaults) { 
        my $policy_attr_name = "go_$policy_name";
        my $sub = sub {
            # $policy->foo($attr, ...)
            #carp "$policy_name($_[1],...)";
            # return the policy default value unless an attribute overrides it
            return ($_[1] && exists $_[1]->{$policy_attr_name})
                ? $_[1]->{$policy_attr_name}
                : $policy_default;
        };
        no strict 'refs';
        *{$class . '::' . $policy_name} = $sub;
    }
}

sub AUTOLOAD {
    carp "Unknown policy name $AUTOLOAD used";
    return undef;
}

sub new {
    my ($class, $args) = @_;
    my $policy = {};
    bless $policy, $class;
}

sub DESTROY { };

1;
