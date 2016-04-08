package TestDbSchema::Result::User;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components(
  "UserBasedAccess",
);

__PACKAGE__->table("User");

__PACKAGE__->add_columns(
  "id" => {
    data_type => "integer",
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "name" => {
    data_type => "text",
    is_nullable => 0,
  },
  "isAdmin" => {
    accessor => "global_admin",
    data_type => "boolean",
    default_value => 0,
    is_nullable => 0,
  },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->has_many(
  "posts",
  "TestDbSchema::Result::Post",
  { "foreign.owner_id" => "self.id" },
);

__PACKAGE__->meta->make_immutable;

sub user_name : method
{
    my $self = shift;
    return $self->name;
}
1;
