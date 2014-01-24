#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use GD;
use Geo::SRTM::Lookup;

use constant WIDTH  => 1280;
use constant HEIGHT => 740;

die "Please define SRTM_DIR"
 unless defined $ENV{SRTM_DIR};

my $lu = Geo::SRTM::Lookup->new( basedir => $ENV{SRTM_DIR} );

my @hgt = ();

my ( $min, $max );
for ( my $y = 0; $y < HEIGHT; $y++ ) {
  for ( my $x = 0; $x < WIDTH; $x++ ) {
    my $lat = $y * 180 / HEIGHT - 90;
    my $lon = $x * 360 / WIDTH - 180;
    printf "\r[%6d, %6d] [%7.2f, %7.2f]", $x, $y, $lat, $lon;
    my $hgt = $lu->lookup( $lat, $lon );
    next unless defined $hgt;
    $max = $hgt unless defined $max && $max > $hgt;
    $min = $hgt unless defined $min && $min < $hgt;
    $hgt[$x][$y] = $hgt;
  }
}
print "\n";

my $img = GD::Image->new( WIDTH, HEIGHT, 1 );
my $empty = $img->colorAllocate(0, 80, 200);
for ( my $y = 0; $y < HEIGHT; $y++ ) {
  for ( my $x = 0; $x < WIDTH; $x++ ) {
    my $hgt = $hgt[$x][$y];
    if ( defined $hgt ) {
      my $sample = ( $hgt - $min ) * 255 / ( $max - $min );
      my $col = $img->colorAllocate( $sample, $sample, $sample );
      $img->setPixel( $x, $y, $col );
    }
    else {
      $img->setPixel( $x, $y, $empty );
    }
  }
}

{
  open my $fh, '>', 'srtm.png' or die "Can't write srtm.png: $!\n";
  $fh->binmode;
  print $fh $img->png(0);
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

