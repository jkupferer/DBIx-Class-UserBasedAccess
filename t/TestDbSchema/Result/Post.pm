package TestDbSchema::Result::Post;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components(
  "UserBasedAccess",
);

__PACKAGE__->table("Post");

__PACKAGE__->add_columns(
  "id" => {
    data_type => "integer",
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "title" => {
    data_type => "text",
    is_nullable => 0,
  },
  "owner_id" => {
    data_type => "integer",
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "private" => {
    data_type => "boolean",
    default_value => 0,
    is_nullable => 0,
  },
  "last_modified_by" => {
    data_type => "text",
    is_nullable => 0,
  },
  "last_modified_date" => {
    data_type => "text",
    is_nullable => 0,
  },
  "created_by" => {
    data_type => "text",
    is_nullable => 0,
  },
  "created_on_date" => {
    data_type => "text",
    is_nullable => 0,
  },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(
  "owner",
  "TestDbSchema::Result::User",
  { "foreign.id" => "self.owner_id" },
);

__PACKAGE__->meta->make_immutable;
1;
