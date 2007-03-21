package DBI::Util::_accessor;
use strict;
use Carp;
our $VERSION = sprintf("0.%06d", q$Revision$ =~ /(\d+)/);

# based (ever more loosly) on Class::Accessor::Fast

sub new {
    my($proto, $fields) = @_;
    my($class) = ref $proto || $proto;
    $fields ||= {};

    my @dubious = grep { !m/^_/ && !$proto->can($_) } keys %$fields;
    carp "$class doesn't have accessors for fields: @dubious" if @dubious;

    # make a (shallow) copy of $fields.
    bless {%$fields}, $class;
}

sub mk_accessors {
    my($self, @fields) = @_;
    $self->_mk_accessors('make_accessor', @fields);
}

sub _mk_accessors {
    my($self, $maker, @fields) = @_;
    my $class = ref $self || $self;

    # So we don't have to do lots of lookups inside the loop.
    $maker = $self->can($maker) unless ref $maker;

    no strict 'refs';
    foreach my $field (@fields) {
        my $accessor = $self->$maker($field);
        *{$class."\:\:$field"} = $accessor
            unless defined &{$class."\:\:$field"};
    }
    #my $hash_ref = \%{$class."\:\:_accessors_hash};
    #$hash_ref->{$_}++ for @fields;
    # XXX also copy down _accessors_hash of base class(es)
    # so one in this class is complete
    return;
}

sub make_accessor {
    my($class, $field) = @_;
    return sub {
        my $self = shift;
        return $self->{$field} unless @_;
        $self->{$field} = (@_ == 1 ? $_[0] : [@_]);
    };
}

1;
