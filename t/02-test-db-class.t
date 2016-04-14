#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 19;

use FindBin ();
use lib "$FindBin::Bin/../lib";
use lib $FindBin::Bin;

use DateTime ();
our $LOCAL_TZ = DateTime::TimeZone->new( name => 'local' );

# Freeze DateTime time for testing.
BEGIN {
    my $time = time();
    *CORE::GLOBAL::time = sub {
        return $time;
    };
}

use_ok('TestDbSchema');

my $driver	= "SQLite";
my $database 	= "$FindBin::Bin/../db/test.db";
my $dsn = "DBI:$driver:dbname=$database";
my $db;

# Create test database
unlink $database;
system("$FindBin::Bin/../db/sqlite.pl");
system("$FindBin::Bin/../db/insertsql.pl");

ok( $db = TestDbSchema->connect($dsn), "connect to test database" );

my $dbuser;
ok( $dbuser = $db->resultset('User')->find({ name => 'Daniel' }), "find Daniel user" );
ok( $db->effective_user($dbuser), "set effective user to Daniel" );
ok( $db->real_user($dbuser), "set real user to Daniel" );
ok( $dbuser->global_admin, "Daniel is global admin" );

my @posts;
ok( @posts = $dbuser->posts, "get posts by user" );
is( int @posts, 1, "check post count is 1" );

ok( $db->resultset('Post')->create({
    title => 'Global admin test post',
    owner_id => $dbuser->id,
    private => 0,
}), "Create post as global admin Daniel" );

# find Post by title
my $post;
my $now = DateTime->now( time_zone => $LOCAL_TZ  );
ok( $post = $db->resultset('Post')->find({ title => 'Global admin test post' }), 'Find the post by title' );
# Check post modified_by
is( $post->last_modified_by, 'Daniel', 'Find who modified the post...');
# Check post modified_datetime
is( $post->last_modified_date, "$now", 'Find last date post was modified...');
# Check post created_by
is( $post->created_by, 'Daniel', 'Find who created the post...');
# Check post created_datetime
is( $post->created_on_date, "$now", 'Find date post was created on...');

# Verify non-admin can't create post.
ok( $dbuser = $db->resultset('User')->find({ name => 'Will' }), "find Will user" );
ok( $db->effective_user($dbuser), "set effective user to Will" );
ok( $db->real_user($dbuser), "set real user to Will" );
ok( !$dbuser->global_admin, "Will is not global admin" );

eval{
    $db->resultset('Post')->create({
        title => 'Global admin test post',
        owner_id => $dbuser->id,
        private => 0,
    });
};
ok( $@ =~ m/Permission denied/, "Failed to create post as non global admin Will" );

# Verify non-admin can't update 
eval{
    $db->resultset('Post')->update({
        title => 'Global admin test post',
        owner_id => $dbuser->id,
        private => 0,
    });
};
print $@;
# Verify non-admin can't delete 
eval{
    $db->resultset('Post')->delete({
        title => 'Global admin test post',
        owner_id => 0,
        private => 0,
    });
};



# vi: syntax=perl
