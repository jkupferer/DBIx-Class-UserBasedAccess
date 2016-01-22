#!/usr/bin/env perl
use strict;
use warnings;
use Module::Build ();

my $mb = Module::Build->new(
	module_name => 'DBIx::Class::UserBasedAccess',
	license => 'perl',
	requires => {
		# ex. DBI => 1.0,
	},
);
$mb->create_build_script();
