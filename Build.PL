#!/usr/bin/env perl
use strict;
use warnings;
use Module::Build ();

my $mb = Module::Build->new(
    module_name => 'DBIx::Class::UserBasedAccess',
    license => 'perl',
    requires => {
        'DBIx::Class' => undef,
        'Moose' => undef,
        'MooseX::Aliases' => undef,
    },
);
$mb->create_build_script();
