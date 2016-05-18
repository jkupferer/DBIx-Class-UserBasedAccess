=head1 NAME

DBIx::Class::UserBasedAccess - DBIx::Class component for access control

=head1 SYNOPSIS

=head2 Schema Class

    use Moose;
    use MooseX::MarkAsMethods autoclean => 1;
    extends 'DBIx::Class::Schema';

    has 'effective_user'  => (is => 'rw', isa => 'Object');
    has 'real_user'       => (is => 'rw', isa => 'Object');
    has 'bypass_access_checks' => (is => 'rw', isa => 'Bool', default => 0);
    has 'bypass_search_restrictions' => (is => 'rw', isa => 'Bool', default => 0);

=head2 User Result Class

    __PACKAGE__->load_components(
      "UserBasedAccess"
    );

    # User class must implement global_admin function or user table must have
    # it as a accessor.
    sub global_admin : method
    {
        my $self = shift;
        return $self->admin ? 1 : 0;
    }

    # User class may implement a has_priv function that takes a string
    # of the form Type.action and should return 0 or 1 based on whether
    # the user should be allowed to do the specified action on the specified
    # type of object.
    sub has_priv : method
    {
        my $self = shift;
        my($priv) = @_;
        my($type, $action) = split '.', $priv;

        # Maybe our user object has a relationship called privs...
        return 1 if $self->privs->search({ name => '$priv' })->count;

        # Maybe we decided to implement a priv named Type.*...
        return 1 if $self->privs->search({ name => "$type.*" })->count;

        # No access.
        return 0;
    }

    # user_name method or accessor must be provided if the result classes
    # specify a last_modified_by_accessor or created_by_accessor.
    sub user_name : method
    {
        my $self = shift;
        return $self->name;
    }

=head2 In Result Classes

    # Set these constants or methods to enable auto-setting of columns to
    # track create and modification user and date/time.
    use constant last_modified_by_accessor => 'muser';
    use constant last_modified_datetime_accessor => 'mtime';
    use constant created_by_accessor => 'cuser';
    use constant create_datetime_accessor => 'ctime';

    # General access rights for a user for this object.
    sub __user_allowed_actions : method
    {
        my($self, $user) = @_;

        # Allow full access to global admins
        return qw(delete insert update) if $user->global_admin;

        # Allow update if user id matches object's "owner_id".
        return qw(update) if $self->owner_id == $user->id;

        # No actions allowed otherwise.
        return qw();
    }

    # Example of custom check with error message
    sub __user_may_update : method
    {
        my($self, $user) = @_;

        # Example implementing access based on changes or values...
        my %changes = $self->get_dirty_columns;
        return(0, "Not allowed to change monthly charge!") if $changes{monthly_charge};

        # Defer to default behavior of checking __user_allowed_actions() and privs.
        return;
    }

    # You can protect any method on your objects, not just insert, update, delete...
    sub frobnobicate : method
    {
        my($self) = @_;

        # Access check
        my($allow, $err) = $self->user_may('frobnobicate');
        die "$err" if $err;
        die "Permissioned denied to frobnobicate this thing\n" unless $allow;

        # Rest of the method...
    }

=head2 In ResultSet Classes

    package UIC::DBIC::IAM::ResultSet::SomeThing;
    use strict;
    use warnings;
    use base 'DBIx::Class::UserBasedAccess::ResultSet';

    # Searches are by default unrestricted, use user_search_restrictions method
    # to give restrictions to AND onto your queries.
    sub user_search_restrictions : method
    {
        my($self,$user,$attr) = @_;

        # Let's implement a search_restrict attribute on our searches so our
        # calling app can request custom restrictions.
        my $restrict = $attr->{search_restrict} || 'default';

        # User may be undefined... let's block all access in that case.
        return $self->NO_ACCESS unless $user;

        if( $restrict eq 'for_admin' ) {
             # Example where users can only update if the user id is the
             # owner_id.
             return { owner_id => $user->id };
        } elsif( $user->has_priv('select_any') ) {
             # undef means no restrictions, also showing mixing in privs.
             return undef;
        } else {
             # Default restrictions, using a relationship.
             return { some_relation.public => 1 };
        }
    }

=head2 In Code

    my $dbic = My::Schema->connect(...);
    my $user_object = $dbic->resultset('User')->find({ name => 'buffy' });
    $dbic->effective_user($user_object );
    $dbic->real_user( $user_object );

    # ResultSet restrictions place filters on search and find.
    $thing = $dbic->resultset('SomeThing')->find(9999);

    # When rendering a template or UI you might want to check in advance
    # to see if a user has update rights...
    if( $thing->user_may('update') ) {
        # Render edit template...
    } else {
        # Render read-only display template...
    }

    # When performing standard actions action checks are built in.
    my $row;
    eval {
        $row->style('round');
        $row->update();
    };
    if( $@ ) {
        print "Update failed: $@\n";
    } else {
        print "Update successful.\n";
    }

=head1 DESCRIPTION

This DBIx::Class component adds access control and features around user based
access control in a database. The assumption is that in the database there is
some table and result class that represents users authenticating to the
database backed application.

=head2 Understanding Access Control

Access control is managed through ResultSet classes for search and find
restrictions and through Result classes for all other actions. For ResultSet
the restrictions are implemented through user_search_restrictions. For other
actions (insert, update, delete) these are implemented on the Result class
named __user_may_*, __user_allowed_actions or the has_priv method on the user
class.

=head3 ResultSet user_search_restrictions

FIXME - Document This Feature!

=head3 Result __user_may_*

FIXME - Document This Feature!

=head3 Result __user_allowed_actions

FIXME - Document This Feature!

=head3 User has_priv

FIXME - Document This Feature!

=cut

package DBIx::Class::UserBasedAccess;
use base qw(DBIx::Class);
use Moose;
use MooseX::Aliases;
use DateTime ();
use DBIx::Class::UserBasedAccess::ResultSet;
use POSIX qw(strftime);

our $VERSION = '0.001';
our $LOCAL_TZ = DateTime::TimeZone->new( name => 'local' );

### Strictly internal methods ###

# Enforce access rules on insert, update, or delete.
sub __method_protect : method
{
    my($self,$action) = @_;
    my $schema = $self->result_source->schema;

    # This method is only called for actions update, insert, and delete. User
    # information must be present for any of these actions.
    die "Permission denied on $action, real user not set.\n"
        unless $schema->real_user;
    die "Permission denied on $action, effective user not set.\n"
        unless $schema->effective_user;

    # Global admins completely skip invoking check_user_access.
    return if $schema->effective_user->global_admin;

    # check_user_access must return a boolean specifying whether to allow
    # access and may return a message describing why access was denied.
    my($allow, $denial_message) = $self->check_user_access($action, $schema->effective_user);
    return if $allow;

    die $denial_message if $denial_message;

    if( $action eq 'insert' ) {
        die "Permission denied to insert ".$self->result_source->name;
    } else {
        # Die with record id if it should have one.
        die "Permission denied to $action ".$self->result_source->name." ".join(';',$self->id);
    }
}

# Set auto-set columns on insert or update.
sub __set_auto_columns : method
{
    my($self, $action) = @_;
    my $schema = $self->result_source->schema;

    if( $self->can('last_modified_by_accessor') ) {
        my $last_modified_by = $self->last_modified_by_accessor;
        $self->$last_modified_by($schema->real_user->user_name);
    }

    if( $self->can('last_modified_datetime_accessor') ) {
        my $last_modified_datetime = $self->last_modified_datetime_accessor;
        $self->$last_modified_datetime( DateTime->now( time_zone => $LOCAL_TZ  ) );
    }

    if( $action eq 'insert' ) {
        if( $self->result_class->can('created_by_accessor') ) {
            my $created_by = $self->created_by_accessor;
            $self->$created_by($schema->real_user->user_name);
        }

        if( $self->result_class->can('created_datetime_accessor') ) {
             my $created_datetime = $self->result_class->created_datetime_accessor;
             $self->$created_datetime( DateTime->now( time_zone => $LOCAL_TZ ) );
        }
    }
}

=head2 METHODS

=over 4

=item $self->get_meta()

Get metadata about object including what access is granted to the user.

=cut

sub get_meta : method
{
    my $self = shift;
    my $columns_info = $self->columns_info();
    my %meta = (
        columns_info => $columns_info,
        allowed_actions => [ $self->user_allowed_actions ],
    );
    for my $col ( keys %$columns_info ) {
        my $column_info = $columns_info->{$col};
        if( $self->can('column_description') ) {
            $column_info->{description} = $self->column_description($col)
        }
    }
    return \%meta;
}

=item $obj->user_allowed_actions( [$user] )

Return list of actions that are allowed to the specified user. If the user is
not specified then the current effective user is checked.

Subclasses should NOT override user_allowed_actions, but should override
__user_allowed_actions instead.

=cut

sub user_allowed_actions : method
{
    my($self, $user) = @_;
    my $schema = $self->result_source->schema;
    $user ||= $schema->effective_user;

    # If already in bypass mode, then call __user_allowe_actions directly.
    return $self->__user_allowed_actions($user) if $schema->bypass_search_restrictions;

    # Enter bypass mode and get search restrictions.
    my @actions;
    $schema->bypass_search_restrictions( 1 );
    eval { @actions = $self->__user_allowed_actions($user) };
    $schema->bypass_search_restrictions( 0 );
    die $@ if $@;

    return @actions;
}

=item $obj->__user_allowed_actions( $user )

Override this method in subclasses to return list of allowed actions for user.
The user variable is guaranteed to be passed and the bypass_search_restrictions
flag will be handled automatically.

=cut

sub __user_allowed_actions : method
{
    my($self, $user);
    return qw(delete insert update) if $user and $user->global_admin;
    return ();
}

=item $obj->user_may( $action, $user )

Short alias for $obj->check_user_access( $action, $user ).

=cut

alias user_may => 'check_user_access';

=item $obj->check_user_access( $action, $user )

Check if a user is allowed to perform specified action on the object. If user
is undefined then the current effective user will be used for the access
check.

This method is automatically invoked on insert, update, or delete.

To control access classes should implement __user_allowed_actions as well as
__user_may_<$action> methods.

=cut

sub check_user_access : method
{
    my($self, $action, $user) = @_;
    my $schema = $self->result_source->schema;

    # The purpose of bypass_search_restrictions is to allow checks to read any
    # data from the database as required to perform the check. It may be the
    # case that a user does not have access normally to select records to
    # indicate whether their access should be permitted.

    # Mark that we are performing an access check and whether we need to
    # exit the access check.
    my $entered_restriction_bypass = !$schema->bypass_search_restrictions;
    $schema->bypass_search_restrictions( 1 );

    my($allow, $message) = eval {
        # All access checks are based on the database schema's current effective
        # user.
        my $user ||= $schema->effective_user;

        # No actions allowed to anonymous user.
        return 0 unless $user;

        # Allow any action to global admins.
        return 1 if $user and $user->global_admin;

        # Return 1 if in bypass_access_checks mode.
        return 1 if $schema->can('bypass_access_checks')
            and $schema->bypass_access_checks;

        # Defer to function __user_may_<$action> if class implements it.
        my $may_action_check = "__user_may_$action";
        if( $self->can($may_action_check) ) {
            my($allow, $message) = $self->$may_action_check($user);
            return($allow, $message) if defined $allow;
        }

        # Get list of allowed actions and allow or deny based off of this.
        my @allowed_actions = $self->__user_allowed_actions($user);
        return 1 if grep { $_ eq $action } @allowed_actions;

        # Allow action if user has corresponding privilege.
	if( $user->can('has_priv') ) {
            return 1 if $user->has_priv($self->result_source->name . ".$action");
        }

        # Deny
        return 0;
    };
    if( $@ ) {
        warn $@;
        $allow = 0;
        $message = "Error $@";
    }

    # Clear bypass_search_restrictions flag if it was set.
    $schema->bypass_search_restrictions( 0 ) if $entered_restriction_bypass;

    return($allow, $message) if wantarray;
    return $allow;
}

=back

=head2 METHOD OVERRIDES

Several methods from DBIx::Class::Row are overridden to enforce user access rights.

=item delete

Enforce user access rights on delete.

=cut

sub delete : method
{
    my $self = shift;
    $self->__method_protect('delete');
    $self->next::method(@_);
}

=item insert

Enforce user access rights on insert.

=cut

sub insert : method
{
    my $self = shift;
    $self->__method_protect('insert');
    $self->__set_auto_columns('insert');
    $self->next::method(@_);
}

=item copy

Enforce user access rights on copy. Access check implemented as action insert.

=cut

sub copy : method
{
    my $self = shift;
    # Treat copy as insert for method protection
    $self->__method_protect('insert');
    $self->__set_auto_columns('insert');
    $self->next::method(@_);
}

=item update

Enforce user access rights on update.

=cut

sub update : method
{
    my $self = shift;
    $self->set_inflated_columns(@_) if @_;
    $self->__method_protect('update');
    $self->__set_auto_columns('update');
    $self->next::method();
}

=item update_or_insert

Enforce user access rights on update_or_insert, treating it as either an
update or insert action based on the in_storage value.

=cut

sub update_or_insert : method
{
    my $self = shift;
    my $action = $self->in_storage ? 'update' : 'insert';
    $self->__method_protect($action);
    $self->__set_auto_columns($action);
    $self->next::method();
}

=item insert_or_update

Alias for update_or_insert.

=cut

alias insert_or_update => 'update_or_insert';

=back

=head1 COPYRIGHT

FIXME

=head1 AUTHOR

=cut

1;
