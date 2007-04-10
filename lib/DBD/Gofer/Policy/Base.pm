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
    # force connect method (unless overridden by go_connect_method=>'...' attribute)
    # if false: call same method on client as on server
    connect_method => 'connect',
    # force prepare method (unless overridden by go_prepare_method=>'...' attribute)
    # if false: call same method on client as on server
    prepare_method => 'prepare',
    skip_connect_check => 0,
    skip_default_methods => 0,
    skip_prepare_check => 0,
    skip_ping => 0,
    dbh_attribute_update => 'every',
    dbh_attribute_list => ['*'],
    locally_quote => 0,
    locally_quote_identifier => 0,
    cache_parse_trace_flags => 1,
    cache_parse_trace_flag => 1,
    cache_data_sources => 1,
    cache_type_info_all => 1,
    cache_tables => 0,
    cache_table_info => 0,
    cache_column_info => 0,
    cache_primary_key_info => 0,
    cache_foreign_key_info => 0,
    cache_statistics_info => 0,
    cache_get_info => 0,
    cache_func => 0,
);

my $base_policy_file = $INC{"DBD/Gofer/Policy/Base.pm"};

__PACKAGE__->create_policy_subs(\%policy_defaults);

sub create_policy_subs {
    my ($class, $policy_defaults) = @_;

    while ( my ($policy_name, $policy_default) = each %$policy_defaults) { 
        my $policy_attr_name = "go_$policy_name";
        my $sub = sub {
            # $policy->foo($attr, ...)
            #carp "$policy_name($_[1],...)";
            # return the policy default value unless an attribute overrides it
            return (ref $_[1] && exists $_[1]->{$policy_attr_name})
                ? $_[1]->{$policy_attr_name}
                : $policy_default;
        };
        no strict 'refs';
        *{$class . '::' . $policy_name} = $sub;
    }
}

sub AUTOLOAD {
    carp "Unknown policy name $AUTOLOAD used";
    # only warn once
    no strict 'refs';
    *$AUTOLOAD = sub { undef };
    return undef;
}

sub new {
    my ($class, $args) = @_;
    my $policy = {};
    bless $policy, $class;
}

sub DESTROY { };

1;

=head1 AUTHOR AND COPYRIGHT

The DBD::Gofer, DBD::Gofer::* and DBI::Gofer::* modules are
Copyright (c) 2007 Tim Bunce. Ireland.  All rights reserved.

You may distribute under the terms of either the GNU General Public License or
the Artistic License, as specified in the Perl README file.

