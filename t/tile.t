#!perl

use strict;
use warnings;

use Test::More;
use Path::Class;

use Geo::SRTM::Tile;

plan skip_all => 'Please define SRTM_DIR'
 unless defined $ENV{SRTM_DIR};

my $base = dir $ENV{SRTM_DIR};
my $tile_file = file( $base, 'N32W089.hgt' );

{
  my $res = Geo::SRTM::Tile->file_resolution($tile_file);
  is $res, 3600, 'file_resolution';
}

{
  my $tile = Geo::SRTM::Tile->new( filename => $tile_file );
  is $tile->resolution, 3600, 'file_resolution';
  my $ele = $tile->lookup( 0.5, 0.5 );
  is $ele, 93, 'lookup';
}

done_testing();

# vim:ts=2:sw=2:et:ft=perl

