#!/usr/bin/perl

use DBI;
use strict;
use warnings;

my $driver	= "SQLite";
my $database 	= "test.db";
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
		      or die $DBI::errstr;
print "Opened database successfully\n";

# SELECT from USER database
print "USER TABLE\n----------\n";
my $stmt = qq(SELECT id, name, isAdmin from USER;);
my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;
if($rv < 0){
	print $DBI::errstr;
}

while(my @row = $sth->fetchrow_array()){
	print "id = ". $row[0] . "\n";
	print "name = ". $row[1]. "\n";
	print "isAdmin = ". $row[2] ."\n";
}

print "Operation done successfully on USER table\n";

# SELECT from POST database
print "POST TABLE\n----------\n";
my $stmt2 = qq(SELECT id, title, owner_id, private, last_modified_by, last_modified_date, created_by, created_on_date from POST;);
my $sth2 = $dbh->prepare( $stmt2 );
my $rv2 = $sth2->execute() or die $DBI::errstr;
if($rv2 < 0){
	print $DBI::errstr;
}

while(my @row = $sth2->fetchrow_array()){
	print "ID = ". $row[0] . "\n";
	print "TITLE = ". $row[1]. "\n";
	print "OWNER_ID = ". $row[2] ."\n";
	print "PRIVATE = ". $row[3] . "\n";
	print "LAST_MODIFIED_BY = ". $row[4] ."\n";
	print "LAST_MODIFIED_DATE = ". $row[5] ."\n";
	print "CREATED_BY = ". $row[6] ."\n";
	print "CREATED_ON_DATE = ". $row[7] ."\n";
}

print "Operation done successfully on POST table\n";

#USER auth for the POST table
my $get_name;
					
$dbh->disconnect();
