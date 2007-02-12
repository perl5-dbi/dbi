package DBI::Gofer::Transport::mod_perl;

use strict;
use warnings;

use DBI::Gofer::Execute;

use Apache::Constants qw(OK);

use base qw(DBI::Gofer::Transport::Base);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

my $transport = __PACKAGE__->new();

my %executor_configs;
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
            die "$uri: GoferConfig '$config_name' not defined"
                unless $config_name eq 'default'
                   and !$r_dir_config->get('GoferConfig');
            next;
        }
        for my $type (qw(require default force)) {
            my $type_config = $config->{$type};
            next if !$type_config or !%$type_config;
            warn "$uri: GoferConfig $config_name $type (@{[ %$type_config ]})\n";
            my $merged = $merged_config{$type} ||= {};
            $merged->{$_} = $type_config->{$_} for keys %$type_config;
        }
    }
    my $executor = DBI::Gofer::Execute->new(\%merged_config);
    return $executor;
}


sub configuration { # one-time setup from httpd.conf
    my ($self, $configs) = @_;
    %executor_configs = %$configs;
}

1;

__END__

also need a CGI/FastCGI transport
