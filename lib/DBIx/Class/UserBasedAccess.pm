=head1 NAME

DBIx::Class::UserBasedAccess - DBIx::Class component for access control

=head1 SYNOPSIS

=head2 Schema Class

    use Moose;
    use MooseX::MarkAsMethods autoclean => 1;
    extends 'DBIx::Class::Schema';

    has 'effective_user'  => (is => 'rw', isa => 'Object');
    has 'real_user'       => (is => 'rw', isa => 'Object');
    has 'bypass_search_restrictions' => (is => 'rw', isa => 'Bool', default => 0);

=head2 User Result Class

    __PACKAGE__->load_components(
      "UserBasedAccess"
    );

    # Class must implement global_admin function or user table must have
    # it as a accessor.
    sub global_admin : method
    {
        my $self = shift;
        return $self->admin ? 1 : 0;
    }

    # user_name method or accessor must be provided if the result classes
    # specify a last_modified_by_accessor or created_by_accessor.
    sub user_name : method
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

    sub __user_allowed_actions : method
    {
        my($self, $user) = @_;

        # Allow select when no effective user is set.
        return qw(select) unless $user;

        # Allow full access to global admins
        return qw(delete insert select update) if $user->global_admin;

        # Allow select and update if user id matches object's "owner_id".
        return qw(select update) if $self->owner_id == $user->id;

        # Everyone else only has select access.
        return qw(select);
    }

    # Example of custom check with error message
    sub __user_may_update : method
    {
        my($self, $user) = @_;

        my %changes = $self->get_dirty_columns;
        return(0, "Not allowed to change monthly charge!") if $changes{monthly_charge};

        # Defer to default behavior of checking __user_allowed_actions().
        return;
    }

=head2 In Code

    my $dbic = My::Schema->connect(...);
    my $user_object = $dbic->resultset('User')->find({ name => 'buffy' });
    $dbic->effective_user($user_object );
    $dbic->real_user( $user_object );

    my $row;
    eval {
        $row = $dbic->resultset('Widget')->find(9999);
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
             my $create_datetime = $self->result_class->create_datetime_accessor;
             $self->$create_datetime( DateTime->now( time_zone => $LOCAL_TZ ) );
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

    return $self->__user_allowed_actions($user) if $schema->bypass_search_restrictions;

    $schema->bypass_search_restrictions( 1 );
    my @actions = $self->__user_allowed_actions($user);
    $schema->bypass_search_restrictions( 0 );

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
    return qw(delete insert select update) if $user->global_admin;
    return qw(select);
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

    # The purpose of bypass_search_restrictions is to allow checks to read any data from
    # the database as required to perform the check. It may be the case that a
    # user does not have access normally to select records to indicate whether
    # their access should be permitted.

    # Allow any select if we are in an access check.
    return 1 if $action eq 'select' and $schema->bypass_search_restrictions;

    # Mark that we are performing an access check and whether we need to
    # exit the access check.
    my $entered_restriction_bypass = !$schema->bypass_search_restrictions;
    $schema->bypass_search_restrictions( 1 );

    my $ret = eval {
        # All access checks are based on the database schema's current effective
        # user.
        my $user ||= $schema->effective_user;

        # Only action select is allowed anonymous
        return 0 unless $user or $action eq 'select';

        # Allow any action to global admins.
        return 1 if $user and $user->global_admin;

        # Defer to function __user_may_<$action> if class implements it.
        my $may_action_check = "__user_may_$action";
        if( $self->can($may_action_check) ) {
            my($allow, $message) = $self->$may_action_check($user);
            return($allow, $message) if defined $allow;
        }

        # Get list of allowed actions and allow or deny based off of this.
        my @allowed_actions = $self->__user_allowed_actions($user);
        return 1 if grep { $_ eq $action } @allowed_actions;

        # Deny
        return 0;
    };
    if( $@ ) {
        warn $@;
        $ret = 0;
    }

    # Clear bypass_search_restrictions flag if it was set.
    $schema->bypass_search_restrictions( 0 ) if $entered_restriction_bypass;

    return $ret;
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
