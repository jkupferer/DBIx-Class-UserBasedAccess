#!/usr/bin/perl

use DBI;
use strict;

my $driver	= "SQLite";
my $database	= "test.db";
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
                      or die $DBI::errstr;
print "Opened database sucessfully\n";



# Insert information into database

# Create user Daniel with Admin privilages
my $stmt = qq(INSERT INTO USER (id,name,isAdmin)
	VALUES (1, 'Daniel', 1)); 
my $rv = $dbh->do($stmt) or die $DBI::errstr;
# Create 2 NON-Admins
$stmt = qq(INSERT INTO USER (id,name,isAdmin)
	VALUES (2, 'Jonathan', 0));
my $rv = $dbh->do($stmt) or die $DBI::errstr;

$stmt = qq(INSERT INTO USER (id,name,isAdmin)
 	VALUES (3, "Will", 0));
my $rv = $dbh->do($stmt) or die $DBI::errstr;

print "Records created for USER table successfully\n";

# Create data for POST table
my $stmt2 = qq(INSERT INTO POST (id,title,owner_id,private,last_modified_by,last_modified_date,created_by,created_on_date)
	VALUES (1, 'POSTTEST', 1,1,'Jan-25-2016','Daniel','Jan-25-2016','Jan-25-2016')); 
my $rv2 = $dbh->do($stmt2) or die $DBI::errstr;

print "Records created for USER table successfully\n";

$dbh->disconnect();

