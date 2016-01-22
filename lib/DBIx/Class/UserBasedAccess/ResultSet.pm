package DBIx::Class::UserBasedAccess::ResultSet;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';

=item $rs->get_user_search_restrictions($user, $attr)

Return query to restrict search results to only include results for which the
user should have access.

=cut

sub get_user_search_restrictions
{
    my($self, $user, $attr) = @_;
    my $schema = $self->result_source->schema;
    my $save_effective_user;

    $schema->in_access_check(1);

    # Call user_search_restrictions to get query.
    my($query);
    eval {
        $query = $self->user_search_restrictions($user, $attr);
    };
    my $err = $@;

    # Exit access check mode
    $schema->in_access_check(0);

    # Rethrow error if error occurred while calling user_search_restrictions.
    die $err if $err;

    # user_search_restrictions indicates no sequrity filter query.
    return unless $query;

    # Make certain that columns used in security query are part of results
    # returned. If columns are not specified, then query implies that all
    # columns should be returned.
    #
    # This only tries to find the obvious cases. Classes may need to manipulate
    # columns attribute in user_search_restrictions.
    my $result_source = $self->result_source;
    my $cols = $attr->{cols} ? 'cols' : 'columns';
    if( $attr->{$cols} and 'ARRAY' eq ref $attr->{$cols} ) {
        my @add_cols;
        if( 'HASH' eq ref $query ) {
            # Most queries will be hashes.
            @add_cols = keys %$query;
        } elsif( 'ARRAY' eq ref $query ) {
            # Arrays are hard... just take a rough stab at it.
            @add_cols = grep { !ref($_) } @$query;
        }

        for my $c ( @add_cols ) {
            # Strip off 'me.' from column names for simplicity.
            $c =~ s/^me\.//;
            if( $c =~ m/^(\w+)\.(\w+)$/ ) {
                my($r);
                ($r, $c) = ($1, $2);
                next unless $result_source->has_relationship($r);
                next unless $result_source->related_source->has_column($c);
                push @{$attr->{$cols}}, "$r.$c"
                    unless grep {$_ eq "$r.$c"} @{$attr->{$cols}};
            } else {
                next unless $result_source->has_column($c);
                push @{$attr->{$cols}}, "me.$c"
                    unless grep {$_ eq $c or $_ eq "me.$c"} @{$attr->{$cols}};
            }
        }
    }

    return $query;
}

sub find
{
    my $self = shift;
    my $obj = $self->next::method(@_);
    return unless $obj;

    my $schema = $self->result_source->schema;
    my $save_effective_user;

    return $obj if $schema->in_access_check;
    $schema->in_access_check(1);

    my $permit_access = $obj->check_user_access('select');

    $schema->in_access_check(0);

    return unless $permit_access;
    return $obj;
}

sub search
{
    my $self = shift;
    my($query, $attr) = @_;
    my $schema = $self->result_source->schema;

    # Perform normal search if already in an access_check and no
    # user_search_restrictions implemented for this result set.
    return $self->next::method($query, $attr)
      if $schema->can('in_access_check') && $schema->in_access_check
      or ! $self->can('user_search_restrictions');

    my $effective_user_accessor = $schema->can('effective_user') ? 'effective_user' : 'effectiveUser';
    my $effective_user = $schema->$effective_user_accessor;

    if( $effective_user ) {
        my $global_admin_accessor = $effective_user->can('global_admin') ? 'global_admin' : 'globalAdmin';
        return $self->next::method($query, $attr) if $effective_user->$global_admin_accessor;
    }

    my $security_query = $self->get_user_search_restrictions($effective_user, $attr);
    return $self->next::method($query, $attr) unless $security_query;

    return $self->next::method({-AND => [$security_query, $query]}, $attr);
}

sub update : method
{
    shift->update_all(@_);
}

sub delete : method
{
    shift->delete_all(@_);
}

sub populate : method
{
    my $self = shift;
    my $schema = $self->result_source->schema;
    my $effective_user_accessor = $schema->can('effective_user') ? 'effective_user' : 'effectiveUser';
    my $effective_user = $schema->$effective_user_accessor;
    die "Permission denied, effective user not set.\n" unless $effective_user;
    my $global_admin_accessor = $effective_user->can('global_admin') ? 'global_admin' : 'globalAdmin';
    die "Permission denied to call populate, not admin user.\n" unless $effective_user->global_admin_accessor;
    $self->next::method(@_);
}

1;