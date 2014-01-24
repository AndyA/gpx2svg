#!perl

use strict;
use warnings;

use Test::More;
use Path::Class;

use Geo::SRTM::Lookup;

plan skip_all => 'Please define SRTM_DIR'
 unless defined $ENV{SRTM_DIR};

my $base = dir $ENV{SRTM_DIR};

{
  is_deeply
   [Geo::SRTM::Lookup->_mk_name( 0, 0 )],
   ["N00E000", 0, 0],
   'lookup 0, 0';
}

{
  my $lu = Geo::SRTM::Lookup->new( basedir => $base );
  ok $lu,     "created OK";
  isa_ok $lu, 'Geo::SRTM::Lookup';

  my $hgt = $lu->lookup( 51.4625814, -0.1685967 );
  is $hgt, 14, 'altitude OK';
}

done_testing();

# vim:ts=2:sw=2:et:ft=perl

