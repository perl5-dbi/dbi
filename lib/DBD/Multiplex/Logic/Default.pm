package DBD::Multiplex::Logic::Default;

use strict;
no strict 'refs';

sub mx_pick_handles {
    my ($parent_handle, $method, $wantarray, $mx_options, @args) = @_;

    my $parent_handle_list = $parent_handle->{'mx_handle_list'} or do {
	return if $method eq 'DESTROY'; # eg prepare() failed
	die "No mx_handle_list attribute when calling $method on $parent_handle";
    };

    my @child_handles = @$parent_handle_list;

    if  (defined(my $mx_master_id = $parent_handle->{mx_master_id})
	&& DBD::Multiplex::mx_is_modify_statement( my $statement=$parent_handle->{Statement} )
    ) {
	$parent_handle->trace_msg(" mx => $method on master only for $statement\n");
	# Consider finding once and storing rather than finding each time.
	@child_handles = grep { $_->{dbd_mx_info}{mx_id} eq $mx_master_id } @child_handles
	    or die "No handles match mx_master_id '$mx_master_id'";

    } elsif ( DBD::Multiplex::mx_is_modify_statement( $statement=$parent_handle->{Statement} ) ){
	# Deligate to 'write' capable servers
	@child_handles = grep { $_->{dbd_mx_info}{mx_type}->{W} == 1 } @child_handles
	    or die "No 'write' capable handles";
    }

    if ($parent_handle->{mx_shuffle} && @child_handles > 1) {
	my $deck = \@child_handles; # ref for in-place shuffle
	my $i = @$deck;
	while (--$i) {
	    my $j = int rand ($i+1);
	    @$deck[$i,$j] = @$deck[$j,$i];
	}
    }

    return @child_handles;
}

1;
