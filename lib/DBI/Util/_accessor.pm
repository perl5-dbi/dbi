package DBI::Util::_accessor;
use strict;
our $VERSION = sprintf("0.%06d", q$Revision: 8696 $ =~ /(\d+)/);

# heavily cut-down (but compatible) version of Class::Accessor::Fast to avoid the dependency

sub new {
    my($proto, $fields) = @_;
    my($class) = ref $proto || $proto;
    $fields = {} unless defined $fields;
    # make a copy of $fields.
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
        *{$class."\:\:$field"}  = $accessor
            unless defined &{$class."\:\:$field"};
    }
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
