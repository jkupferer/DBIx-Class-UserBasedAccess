#!/usr/bin/perl

use DBI;
use strict;
use warnings;

use FindBin ();

my $driver	= "SQLite";
my $database 	= "$FindBin::Bin/test.db";
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1})
		      or die $DBI::errstr;

print "Opened database sucessfully\n";

# Create USER table
my $stmt = qq(CREATE TABLE USER
    (ID INTEGER PRIMARY KEY AUTOINCREMENT,
    name    TEXT	NOT NULL,
    isAdmin BOOLEAN  NOT NULL););

my $rv = $dbh->do($stmt);

if($rv < 0){
	print $DBI::errstr;
} else {
	print " USER table created successfully\n";
}
# Create POST Table
my $stmt2 = qq(CREATE TABLE POST
(	ID INTEGER  PRIMARY KEY	AUTOINCREMENT,
    title       TEXT	NOT NULL,
    owner_id    INT   	NOT NULL,
    private		BOOLEAN	NOT NULL,
    last_modified_by	TEXT	NOT NULL,
    last_modified_date 	TEXT	NOT NULL,
    created_by	  	TEXT	NOT NULL,
    created_on_date	  	TEXT	NOT NULL););

my $rv2 = $dbh->do($stmt2);

if($rv2 < 0){
	print $DBI::errstr;
} else {
	print " POST Table created successfully\n";
}
$dbh->disconnect();
     
