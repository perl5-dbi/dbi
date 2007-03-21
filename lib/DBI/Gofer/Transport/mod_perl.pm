package DBI::Gofer::Transport::mod_perl;

use strict;
use warnings;

use Sys::Hostname qw(hostname);
use DBI::Gofer::Execute;

use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );
BEGIN {
  if (MP2) {
      warn "NOT RECENTLY TESTED";
    require Apache2::RequestIO;
    require Apache2::RequestRec;
    require Apache2::RequestUtil;
    require Apache2::Const;
    Apache2::Const->import(-compile => qw(OK SERVER_ERROR));
  } else {
    require Apache::Constants;
    Apache::Constants->import(qw(OK SERVER_ERROR));
  }
}

use Apache::Util qw(escape_html);

use base qw(DBI::Gofer::Transport::Base);

our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/o);

my $hostname = hostname();
my $transport = __PACKAGE__->new();

my %executor_configs = ( default => { } );
my %executor_cache;

my %apache_status_menu_items = (
    DBI_handles => [ 'DBI Handles', \&apache_status_dbi_handles ],
    DBI_gofer   => [ 'DBI Gofer',   \&apache_status_dbi_gofer ],
);
my $apache_status_class;
if (MP2) {
    $apache_status_class = "Apache2::Status" if Apache2::Module::loaded('Apache2::Status');
}
elsif ($INC{'Apache.pm'}                       # is Apache.pm loaded?
       and Apache->can('module')               # really?
       and Apache->module('Apache::Status')) { # Apache::Status too?
       $apache_status_class = "Apache::Status";
}
if ($apache_status_class) {
    while ( my ($url, $menu_item) = each %apache_status_menu_items ) {
        $apache_status_class->menu_item($url => @$menu_item);
    }
}


sub handler : method {
    my $self = shift;
    my $r = shift;

    eval {
        my $executor = $executor_cache{ $r->uri } ||= $self->executor_for_uri($r);

        $r->read(my $frozen_request, $r->headers_in->{'Content-length'});
        my $request = $transport->thaw_data($frozen_request);

        my $response = $executor->execute_request( $request );

        my $frozen_response = $transport->freeze_data($response);
        print $frozen_response;
    };
    if ($@) {
        chomp $@;
        $r->custom_response(SERVER_ERROR, "$@ version $VERSION (DBI $DBI::VERSION) on $hostname");
        return SERVER_ERROR;
    }

    return OK;
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


sub configuration {           # one-time setup from httpd.conf
    my ($self, $configs) = @_;
    while ( my ($config_name, $config) = each %$configs ) {
        my @bad = grep { not exists $proto_config->{$_} } keys %$config;
        warn "Unknown keys in $self configuration '$config_name': @bad\n"
            if @bad;
    }
    %executor_configs = %$configs;
}


# --------------------------------------------------------------------------------
# XXX --- these should be moved into a separate module (Apache::Status::DBI?)
# menu item for Apache::Status
sub apache_status_dbi_handles {
    my($r, $q) = @_;
    my @s = ("<pre>",
        "<b>DBI $DBI::VERSION - Drivers, Connections and Statements</b><p>\n",
    );
    
    my %drivers = DBI->installed_drivers();
    push @s, sprintf("%d drivers loaded: %s<p>", scalar keys %drivers, join(", ", keys %drivers));

    while ( my ($driver, $h) = each %drivers) {
        my $version = do { no strict; ${"DBD::${driver}::VERSION"} || 'undef' };
        my @children = grep { defined } @{$h->{ChildHandles}};

        push @s, sprintf "<hr><b>DBD::$driver</b>  <font size=-2 color=grey>version $version,  %d dbh (%d cached, %d active)  $h</font>\n\n",
            scalar @children, scalar keys %{$h->{CachedKids}||{}}, $h->{ActiveKids};

        @children = sort { ($a->{Name}||"$a") cmp ($b->{Name}||"$b") } @children;
        push @s, _apache_status_dbi_handle($_, 1) for @children;
    }

    push @s, "<hr></pre>";
    return \@s;
}

sub _apache_status_dbi_handle {
    my ($h, $level) = @_;
    my $pad = "    " x $level;
    my $type = $h->{Type};
    my @children = grep { defined } @{$h->{ChildHandles}};
    my @boolean_attr = qw(
        Active Executed RaiseError PrintError ShowErrorStatement PrintWarn
        CompatMode InactiveDestroy HandleError HandleSetErr
        ChopBlanks LongTruncOk TaintIn TaintOut Profile);
    my @scalar_attr = qw(
        ErrCount TraceLevel FetchHashKeyName LongReadLen
    );
    my @scalar_attr2 = qw();

    my @s;
    if ($type eq 'db') {
        push @s, sprintf "DSN \"<b>%s</b>\"  <font size=-2 color=grey>%s</font>\n", $h->{Name}, $h;
        @children = sort { ($a->{Statement}||"$a") cmp ($b->{Statement}||"$b") } @children;
        push @boolean_attr, qw(AutoCommit);
        push @scalar_attr,  qw(Username);
    }
    else {
        push @s, sprintf "    sth  <font size=-2 color=grey>%s</font>\n", $h;
        push @scalar_attr2, qw(NUM_OF_PARAMS NUM_OF_FIELDS CursorName);
    }

    push @s, sprintf "%sAttributes: %s\n", $pad,
        join ", ", grep { $h->{$_} } @boolean_attr;
    push @s, sprintf "%sAttributes: %s\n", $pad,
        join ", ", map { "$_=".DBI::neat($h->{$_}) } @scalar_attr;
    if (my $sql = escape_html($h->{Statement} || '')) {
        $sql =~ s/\n/ /g;
        push @s, sprintf "%sStatement: <b>%s</b>\n", $pad, $sql;
        my $ParamValues = $type eq 'st' && $h->{ParamValues};
        push @s, sprintf "%sParamValues: %s\n", $pad,
                join ", ", map { "$_=".DBI::neat($ParamValues->{$_}) } sort keys %$ParamValues
            if $ParamValues && %$ParamValues;
    }
    push @s, sprintf "%sAttributes: %s\n", $pad,
        join ", ", map { "$_=".DBI::neat($h->{$_}) } @scalar_attr2
        if @scalar_attr2;
    push @s, sprintf "%sRows: %s\n", $pad, $h->rows
        if $type eq 'st' || $h->rows != -1;
    push @s, sprintf "%sError: %s %s\n", $pad,
        $h->err, escape_html($h->errstr) if $h->err;
    push @s, sprintf "    sth: %d (%d cached, %d active)\n",
        scalar @children, scalar keys %{$h->{CachedKids}||{}}, $h->{ActiveKids}
        if @children;
    push @s, "\n";

    push @s, map { _apache_status_dbi_handle($_, $level + 1) } @children;

    return @s;
}
# --------------------------------------------------------------------------------


sub apache_status_dbi_gofer {
    my($r, $q) = @_;
    my @s = ("<pre>",
        "<b>DBI::Gofer::Transport::mod_perl $VERSION</b><p>\n",
    );
    require Data::Dumper;
    local $Data::Dumper::Indent    = 1;
    local $Data::Dumper::Terse     = 1;
    local $Data::Dumper::Useqq     = 1;
    local $Data::Dumper::Sortkeys  = 1;
    local $Data::Dumper::Quotekeys = 0;
    local $Data::Dumper::Deparse   = 0;
    local $Data::Dumper::Purity    = 0;
    push @s, escape_html( Data::Dumper::Dumper(\%executor_cache) );
    return \@s;
}

1;

__END__

=head1 NAME
    
DBI::Gofer::Transport::mod_perl - DBD::Gofer server-side transport for http

=head1 SYNOPSIS

In httpd.conf:

    <Location /gofer>
        SetHandler perl-script 
        PerlHandler DBI::Gofer::Transport::mod_perl
    </Location>

For the client-side see L<DBD::Gofer::Transport::http>.

=head1 DESCRIPTION

This module implements a DBD::Gofer server-side http transport for mod_perl.
After configuring this into your httpd.conf, users will be able to use the DBI
to connect to databases via your apache httpd.

=head1 CONFIGURATION

Rather than provide a DBI proxy that will connect to any database as any user,
you may well want to restrict access to just one or a few databases.

Or perhaps you want the database passwords to be stored only in httpd.conf so
you don't have to maintain them in all your clients. In this case you'd
probably want to use standard https security and authentication.

These kinds of configurations are supported by DBI::Gofer::Transport::mod_perl.

The most simple configuration looks like:
                 
    <Location /gofer>
        SetHandler perl-script
        PerlHandler DBI::Gofer::Transport::mod_perl
    </Location>

That's equivalent to:

    <Perl>
        DBI::Gofer::Transport::mod_perl->configuration({
            default => {
                default_connect_dsn => undef,
                forced_connect_dsn  => undef,
                default_connect_attributes => { },
                forced_connect_attributes  => { },
            },
        });
    </Perl>

    <Location /gofer/example>
        SetHandler perl-script
        PerlSetVar GoferConfig default
        PerlHandler DBI::Gofer::Transport::mod_perl
    </Location>

The DBI::Gofer::Transport::mod_perl->configuration({...}) call defines named configurations.
The C<PerlSetVar GoferConfig> clause specifies the configuration to be used for that location.

XXX add detail including specific examples

A single location can specify multiple configurations using C<PerlAddVar>:

        PerlSetVar GoferConfig default
        PerlAddVar GoferConfig example_foo
        PerlAddVar GoferConfig example_bar

in which case the configurations are merged with any entries in later
configurations overriding those in earlier ones. In this way a small number of
configurations can be mix-n-matched to create specific configurations for
specific location urls.

=head1 AUTHOR AND COPYRIGHT

The DBD::Gofer, DBD::Gofer::* and DBI::Gofer::* modules are
Copyright (c) 2007 Tim Bunce. Ireland.  All rights reserved.

You may distribute under the terms of either the GNU General Public License or
the Artistic License, as specified in the Perl README file.


=head1 SEE ALSO

L<DBD::Gofer> and L<DBD::Gofer::Transport::http>.

=cut

