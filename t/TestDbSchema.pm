package TestDbSchema;
use Moose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;

has 'effective_user'  => (is => 'rw', isa => 'Object', clearer => 'clear_effective_user');
has 'real_user'       => (is => 'rw', isa => 'Object', clearer => 'clear_real_user');
has 'bypass_access_checks' => (is => 'rw', isa => 'Bool', default => 0);
has 'bypass_search_restrictions' => (is => 'rw', isa => 'Bool', default => 0);

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
