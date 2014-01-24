#!perl

use strict;
use warnings;

use Test::More;
use Path::Class;

use Geo::SRTM::Tile;

plan skip_all => 'Please define SRTM_DIR'
 unless defined $ENV{SRTM_DIR};

my $base = dir $ENV{SRTM_DIR};

my $tile = file( $base, 'N32W089.hgt' );

my $res = Geo::SRTM::Tile->file_resolution($tile);

is $res, 3600, 'file_resolution';

done_testing();

# vim:ts=2:sw=2:et:ft=perl

