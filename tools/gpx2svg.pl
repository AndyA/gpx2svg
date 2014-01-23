#!/usr/bin/env perl

use autodie;
use strict;
use warnings;

use Data::Dumper;
use GIS::Distance;
use Geo::Gpx;
use Geo::Mercator;
use Getopt::Long;
use List::Util qw( min max );
use SVG;

my %O = (
  trkfile => undef,
  elefile => undef,
  tracks  => 1,
  routes  => 1,
  size    => '1000x1000',
  vscale  => 100,
  border  => 50,
  eps     => 1,
);

# Potted styles

my %STYLE = (
  track => {
    'fill-opacity' => 0,
    'stroke-width' => '1',
    'stroke'       => 'rgb(0, 0, 0)',
  },
  track_tick => {
    'fill-opacity' => 0,
    'stroke-width' => '2',
    'stroke'       => 'rgb(200, 0, 0)',
  },
  track_dot => {
    'fill-opacity' => 0,
    'fill-opacity' => 0.5,
    'stroke-width' => '1',
    'fill'         => 'rgb(200, 0, 0)',
    'stroke'       => 'rgb(0, 0, 0)',
  },
  elevation => {
    'fill-opacity' => 0.5,
    'stroke-width' => '1',
    'stroke'       => 'rgb(0, 0, 0)',
    'fill'         => 'rgb(0, 100, 0)',
  },
);

GetOptions(
  't:s'      => \$O{trkfile},
  'e:s'      => \$O{elefile},
  'vscale:i' => \$O{vscale},
) or syntax();

unless ( defined $O{trkfile} || defined $O{elefile} ) {
  print "Please specify one or both of\n",
   "   -t track.svg     (generate track file)\n",
   "or -e elevation.svg (generate elevation file)\n";
  exit 1;
}

die "Bad page size\n" unless $O{size} =~ /^(\d+)x(\d+)$/;
@O{ 'width', 'height' } = ( $1, $2 );

my @pt = ();
for my $fn (@ARGV) {
  print "Loading $fn\n";
  my $gpx = load_gpx($fn);
  if ( $O{tracks} ) {
    push @pt, @{ $gpx->tracks || [] };
  }
  if ( $O{routes} ) {
    for my $rte ( @{ $gpx->routes || [] } ) {
      push @pt,
       {name     => $rte->{name},
        segments => [{ points => $rte->{points} }],
       };
    }
  }
}

if ( defined( my $trkfile = $O{trkfile} ) ) {
  print "Drawing track\n";
  my $svg = make_track( \@pt );
  print "Writing track to $trkfile\n";
  open my $of, '>', $trkfile;
  print $of $svg->xmlify;
}

if ( defined( my $elefile = $O{elefile} ) ) {
  print "Drawing elevation profile\n";
  my $svg = make_profile( \@pt );
  print "Writing elevation profile to $elefile\n";
  open my $of, '>', $elefile;
  print $of $svg->xmlify;
}

sub make_track {
  my $pt   = shift;
  my @leg  = ();
  my $bbox = [undef, undef, undef, undef];
  for my $leg (@$pt) {
    print "Plotting ", $leg->{name}, "\n";
    my ( $xv, $yv ) = ( [], [] );
    my @pts = flatten($leg);
    for my $pt (@pts) {
      my ( $x, $y ) = mercate( $pt->{lat}, $pt->{lon} );
      push @$xv, $x;
      push @$yv, $y;
    }
    push @leg, { xv => $xv, yv => $yv };
    grow_bbox( $bbox, $xv, $yv );
  }

  my $width  = $O{width};
  my $height = $O{height};

  my $scaler = make_scaler( $width, $height, $bbox, $O{border} );
  my $svg = SVG->new( width => $width, height => $height );

  for my $leg (@leg) {
    my ( $xv, $yv, $intro ) = @{$leg}{ 'xv', 'yv', 'intro' };
    $scaler->( $xv, $yv );
    my $points = $svg->get_path(
      x     => $xv,
      y     => $yv,
      -type => 'polyline',
    );
    $svg->polyline( %$points, style => $STYLE{track} );
    $svg->circle(
      cx    => $xv->[0],
      cy    => $yv->[0],
      r     => 8,
      style => $STYLE{track_dot}
    );
  }
  return $svg;
}

sub make_profile {
  my $pt  = shift;
  my $gis = GIS::Distance->new;

  my @leg  = ();
  my $dist = 0;
  my $maxy = 0;
  for my $leg (@$pt) {
    print "Plotting ", $leg->{name}, "\n";
    my ( $plat, $plon );
    my ( $xv, $yv ) = ( [], [] );
    my $left = $dist;
    my @pts  = flatten($leg);
    for my $pt (@pts) {
      $dist += $gis->distance( $plat, $plon, $pt->{lat}, $pt->{lon} )->metres
       if defined $plat;
      push @$xv, $dist;
      push @$yv, $pt->{ele} * $O{vscale};
      $maxy = $pt->{ele} if $pt->{ele} > $maxy;
      ( $plat, $plon ) = ( $pt->{lat}, $pt->{lon} );
    }
    # close polygon
    push @$xv, $xv->[-1], $left;
    push @$yv, 0, 0;
    push @leg, [$xv, $yv];
  }

  my $width  = $O{width};
  my $height = $O{height};

  my $scaler
   = make_scaler( $width, $height, [0, 0, $dist, $maxy], $O{border} );
  my $svg = SVG->new( width => $width, height => $height );

  my $fill = sequence( 'rgb(0, 100, 0)', 'rgb(100, 0, 0)' );

  for my $leg (@leg) {
    my ( $xv, $yv ) = @$leg;
    $scaler->( $xv, $yv );
    #    for my $i ( 0 .. $#$xv ) {
    #      printf "%8.3f, %8.3f\n", $xv->[$i], $yv->[$i];
    #    }
    my $points = $svg->get_path(
      x       => $xv,
      y       => $yv,
      -type   => 'polyline',
      -closed => 'true',
    );
    my $style = { %{ $STYLE{elevation} } };
    $style->{fill} = $fill->();
    $svg->polyline( %$points, style => $style );
  }

  return $svg;
}

sub flatten {
  my $leg = shift;
  return map { @{ $_->{points} } } @{ $leg->{segments} };
}

sub sequence {
  my @seq = @_;
  return sub {
    my $v = shift @seq;
    push @seq, $v;
    return $v;
  };
}

sub bbox {
  my ( $xv, $yv ) = @_;
  return [min(@$xv), min(@$yv), max(@$xv), max(@$yv)];
}

sub grow_bbox {
  my ( $bbox, $xv, $yv ) = @_;
  my $bb2 = bbox( $xv, $yv );
  $bbox->[0] = $bb2->[0]
   unless defined $bbox->[0] && $bbox->[0] < $bb2->[0];
  $bbox->[1] = $bb2->[1]
   unless defined $bbox->[1] && $bbox->[1] < $bb2->[1];
  $bbox->[2] = $bb2->[2]
   unless defined $bbox->[2] && $bbox->[2] > $bb2->[2];
  $bbox->[3] = $bb2->[3]
   unless defined $bbox->[3] && $bbox->[3] > $bb2->[3];
}

sub make_scaler {
  my ( $ow, $oh, $bbox, $border ) = @_;
  $border ||= 0;
  my ( $minx, $miny, $maxx, $maxy ) = @$bbox;
  my $iw     = $maxx - $minx;
  my $ih     = $maxy - $miny;
  my $scale  = min( ( $ow - $border ) / $iw, ( $oh - $border ) / $ih );
  my $xshift = ( $ow - $iw * $scale ) / 2;
  my $yshift = ( $oh - $ih * $scale ) / 2;
  return sub {
    my ( $xv, $yv ) = @_;
    $_ = ( $_ - $minx ) * $scale + $xshift for @$xv;
    $_ = $oh - ( ( $_ - $miny ) * $scale + $yshift ) for @$yv;
  };
}

sub load_gpx {
  my $fn = shift;
  open my $fh, '<', $fn;
  return Geo::Gpx->new( input => $fh );
}

sub syntax {
  print <<EOT;
Syntax: gpx2svg [options] <input.gpx> ...

Options:
   -t tracks.svg      Output track file
   -e elevation.svg   Output elevation profile

EOT
  exit 1;
}

# vim:ts=2:sw=2:sts=2:et:ft=perl
