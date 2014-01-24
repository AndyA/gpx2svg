#!/usr/bin/env perl

use autodie;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use GD;
use Geo::SRTM::Lookup;

use constant SCALE => 'ref/scale.png';

#use constant LAT_MIN => -90;
#use constant LAT_MAX => 90;
#use constant LON_MIN => -180;
#use constant LON_MAX => 180;

#use constant LAT_MIN => 43;
#use constant LAT_MAX => 57;
#use constant LON_MIN => -6;
#use constant LON_MAX => 10;

#use constant LAT_MIN => -20;
#use constant LAT_MAX => 20;
#use constant LON_MIN => -20;
#use constant LON_MAX => 20;

use constant LAT_MIN => 47.5;
use constant LAT_MAX => 60.5;
use constant LON_MIN => -11.5;
use constant LON_MAX => 2.5;

use constant WIDTH => 1800;
use constant HEIGHT =>
 int( WIDTH * ( LAT_MAX - LAT_MIN ) / ( LON_MAX - LON_MIN ) );

$| = 1;

die "Please define SRTM_DIR"
 unless defined $ENV{SRTM_DIR};

my $lu = Geo::SRTM::Lookup->new( basedir => $ENV{SRTM_DIR} );

my $x_to_lon = scaler( 0, WIDTH,  LON_MIN, LON_MAX );
my $y_to_lat = scaler( 0, HEIGHT, LAT_MIN, LAT_MAX );

my %by_tile = ();
for ( my $y = 0; $y < HEIGHT; $y++ ) {
  for ( my $x = 0; $x < WIDTH; $x++ ) {
    my $lat = $y_to_lat->($y);
    my $lon = $x_to_lon->($x);
    my ( $tn, undef, undef ) = Geo::SRTM::Lookup->_mk_name( $lat, $lon );
    push @{ $by_tile{$tn} }, [$x, $y];
  }
}

my @hgt  = ();
my %hist = ();
my ( $min, $max );
my $done = 0;
for my $tn ( keys %by_tile ) {
  for my $cp ( @{ $by_tile{$tn} } ) {
    my ( $x, $y ) = @$cp;
    my $lat = $y_to_lat->($y);
    my $lon = $x_to_lon->($x);
    my $pc  = $done * 100 / ( WIDTH * HEIGHT );
    my ( $tn, undef, undef ) = Geo::SRTM::Lookup->_mk_name( $lat, $lon );
    printf( "\r[%6d, %6d] [%7.2f, %7.2f] %s %6.2f%%",
      $x, $y, $lat, $lon, $tn, $pc );
    $done++;
    my $hgt = $lu->lookup( $lat, $lon );
    next unless defined $hgt;
    $max = $hgt unless defined $max && $max > $hgt;
    $min = $hgt unless defined $min && $min < $hgt;
    $hgt[$x][$y] = $hgt;
    $hist{$hgt}++;
  }
}

print "\nmin: $min, max: $max\n";

my $img = GD::Image->new( WIDTH, HEIGHT, 1 );
my $scale = GD::Image->new(SCALE);
my ( $sw, $sh ) = $scale->getBounds;
my %cc    = ();
my $zero  = $img->colorAllocate( 0, 120, 240 );
my $empty = $img->colorAllocate( 0, 80, 200 );

for ( my $y = 0; $y < HEIGHT; $y++ ) {
  for ( my $x = 0; $x < WIDTH; $x++ ) {
    my $hgt = $hgt[$x][$y];
    if ( defined $hgt ) {
      if ( $hgt == 0 ) {
        $img->setPixel( $x, HEIGHT - 1 - $y, $zero );
      }
      else {
        my $sp = int( ( $hgt - $min ) * $sh / ( $max - $min ) );
        my $col = $cc{$sp} ||= $img->colorAllocate(
          $scale->rgb( $scale->getPixel( $sw / 2, $sh - 1 - $sp ) ) );
        $img->setPixel( $x, HEIGHT - 1 - $y, $col );
      }
    }
    else {
      $img->setPixel( $x, HEIGHT - 1 - $y, $empty );
    }
  }
}

{
  open my $fh, '>', 'srtm.png';
  $fh->binmode;
  print $fh $img->png(0);
}

sub scaler {
  my ( $imin, $imax, $omin, $omax ) = @_;
  return sub {
    my $v = shift;
    return ( $v - $imin ) * ( $omax - $omin ) / ( $imax - $imin ) + $omin;
   }
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

