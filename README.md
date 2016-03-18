# NAME

DBIx::Class::UserBasedAccess - DBIx::Class component for access control

# SYNOPSIS

## Schema Class

    use Moose;
    use MooseX::MarkAsMethods autoclean => 1;
    extends 'DBIx::Class::Schema';

    has 'effective_user'  => (is => 'rw', isa => 'Object');
    has 'real_user'       => (is => 'rw', isa => 'Object');
    has 'bypass_search_restrictions' => (is => 'rw', isa => 'Bool', default => 0);

## User Result Class

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
        my $self = shift;
        return $self->name;
    }

## In Result Classes

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

## In ResultSet Classes

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

## In Code

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

# DESCRIPTION

This DBIx::Class component adds access control and features around user based
access control in a database. The assumption is that in the database there is
some table and result class that represents users authenticating to the
database backed application.

## Understanding Access Control

Access control is managed through ResultSet classes for search and find
restrictions and through Result classes for all other actions. For ResultSet
the restrictions are implemented through user\_search\_restrictions. For other
actions (insert, update, detele) these are implemented on the Result class
named \_\_user\_may\_\*, \_\_user\_allowed\_actions or the has\_priv method on the user
class.

### ResultSet user\_search\_restrictions

FIXME - Document This Feature!

### Result \_\_user\_may\_\*

FIXME - Document This Feature!

### Result \_\_user\_allowed\_actions

FIXME - Document This Feature!

### User has\_priv

FIXME - Document This Feature!

## METHODS

- $self->get\_meta()

    Get metadata about object including what access is granted to the user.

- $obj->user\_allowed\_actions( \[$user\] )

    Return list of actions that are allowed to the specified user. If the user is
    not specified then the current effective user is checked.

    Subclasses should NOT override user\_allowed\_actions, but should override
    \_\_user\_allowed\_actions instead.

- $obj->\_\_user\_allowed\_actions( $user )

    Override this method in subclasses to return list of allowed actions for user.
    The user variable is guaranteed to be passed and the bypass\_search\_restrictions
    flag will be handled automatically.

- $obj->user\_may( $action, $user )

    Short alias for $obj->check\_user\_access( $action, $user ).

- $obj->check\_user\_access( $action, $user )

    Check if a user is allowed to perform specified action on the object. If user
    is undefined then the current effective user will be used for the access
    check.

    This method is automatically invoked on insert, update, or delete.

    To control access classes should implement \_\_user\_allowed\_actions as well as
    \_\_user\_may\_<$action> methods.

## METHOD OVERRIDES

Several methods from DBIx::Class::Row are overridden to enforce user access rights.

- delete

    Enforce user access rights on delete.

- insert

    Enforce user access rights on insert.

- copy

    Enforce user access rights on copy. Access check implemented as action insert.

- update

    Enforce user access rights on update.

- update\_or\_insert

    Enforce user access rights on update\_or\_insert, treating it as either an
    update or insert action based on the in\_storage value.

- insert\_or\_update

    Alias for update\_or\_insert.

# COPYRIGHT

FIXME

# AUTHOR

# POD ERRORS

Hey! **The above document had some coding errors, which are explained below:**

- Around line 430:

    '=item' outside of any '=over'
