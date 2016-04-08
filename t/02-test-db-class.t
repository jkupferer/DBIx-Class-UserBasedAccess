#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 8;

use FindBin ();
use lib "$FindBin::Bin/../lib";
use lib $FindBin::Bin;

use_ok('TestDbSchema');

# Create test database
system("$FindBin::Bin/../db/sqlite.pl");
system("$FindBin::Bin/../db/insertsql.pl");

my $driver	= "SQLite";
my $database 	= "$FindBin::Bin/../db/test.db";
my $dsn = "DBI:$driver:dbname=$database";
my $db;
ok( $db = TestDbSchema->connect($dsn), "connect to test database" );

my $dbuser;
ok( $dbuser = $db->resultset('User')->find({ name => 'Daniel' }), "find Daniel user" );
ok( $db->effective_user($dbuser), "set effective user to Daniel" );
ok( $db->real_user($dbuser), "set real user to Daniel" );
ok( $dbuser->global_admin, "Daniel is global admin" );

my @posts;
ok( @posts = $dbuser->posts, "get posts by user" );
is( int @posts, 1, "check post count is 1" );

# vi: syntax=perl
