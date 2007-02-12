package DBI::Gofer::Transport::mod_perl;

use strict;
use warnings;

use DBI::Gofer::Execute;

use Apache::Constants qw(OK);

use base qw(DBI::Gofer::Transport::Base);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

my $transport = __PACKAGE__->new();

my %executor_configs = ( default => { } );
my %executor_cache;


sub handler ($$) {
    my $self = shift;
    my $r = shift;

    my $executor = $executor_cache{ $r->uri } ||= $self->executor_for_uri($r);

    $r->read(my $frozen_request, $r->header_in('Content-length'));
    my $request = $transport->thaw_data($frozen_request);

    my $response = $executor->execute_request( $request );

    my $frozen_response = $transport->freeze_data($response);
    print $frozen_response;

    return Apache::Constants::OK;
}


my $proto_config = { # defines valid keys and types for exector config
    default_connect_dsn => 1,
    forced_connect_dsn  => 1,
    default_connect_attributes => {},
    forced_connect_attributes  => {},
};


sub executor_for_uri {
    my ($self, $r) = @_;
    my $uri = $r->uri;
    my $r_dir_config = $r->dir_config;

    my @location_configs = $r_dir_config->get('GoferConfig');
    push @location_configs, 'default' unless @location_configs;

    # merge all configs for this location in sequence ('closest' last)
    my %merged_config;
    for my $config_name ( @location_configs ) {
        my $config = $executor_configs{$config_name};
        if (!$config) {
            # die if an unknown config is requested but not defined
            # (don't die for 'default' unless it was explicitly requested)
            die "$uri: GoferConfig '$config_name' not defined";
            next;
        }
        while ( my ($item_name, $proto_type) = each %$proto_config ) {
            next if not exists $config->{$item_name};
            my $item_value = $config->{$item_name};
            if (ref $proto_type) {
                my $merged = $merged_config{$item_name} ||= {};
                warn "$uri: GoferConfig $config_name $item_name (@{[ %$item_value ]})\n"
                    if keys %$item_value;
                $merged->{$_} = $item_value->{$_} for keys %$item_value;
            }
            else {
                warn "$uri: GoferConfig $config_name $item_name: '$item_value'\n"
                    if defined $item_value;
                $merged_config{$item_name} = $item_value;
            }
        }
    }
    my $executor = DBI::Gofer::Execute->new(\%merged_config);
    return $executor;
}


sub configuration { # one-time setup from httpd.conf
    my ($self, $configs) = @_;
    while ( my ($config_name, $config) = each %$configs ) {
        my @bad = grep { not exists $proto_config->{$_} } keys %$config;
        warn "Unknown keys in $self configuration '$config_name': @bad\n"
            if @bad;
    }
    %executor_configs = %$configs;
}

1;

__END__

also need a CGI/FastCGI transport
