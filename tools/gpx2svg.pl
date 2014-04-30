#!/usr/bin/env perl

use autodie;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Data::Dumper;
use GIS::Distance;
use Geo::Gpx;
use Geo::Mercator;
use Geo::SRTM::Lookup;
use Getopt::Long;
use List::Util qw( min max );
use Path::Class;
use SVG;
use URI;

use constant MAPERITIVE => 'Maperitive.Console.exe';
use constant RULES      => 'Default.mrules';

my %O = (
  trkfile    => undef,
  elefile    => undef,
  maperitive => undef,
  tracks     => 1,
  routes     => 1,
  size       => '1000x1000',
  vscale     => 100,
  border     => 50,
  eps        => 1,
  smooth     => 0,
  srtm       => undef,
  force_dem  => 0,
  mp_home    => "$FindBin::Bin/../Maperitive",
  mp_rules   => "work/Rules/Default.mrules",
  xapi_url   => "http://overpass.osm.rambler.ru/cgi/xapi_meta?*",
  proxy      => undef,
  map_aspect => sqrt(2),
);

# Potted styles

my %STYLE = (
  track => {
    'fill-opacity' => 0,
    'stroke-width' => '2',
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
  't:s'       => \$O{trkfile},
  'e:s'       => \$O{elefile},
  'm:s'       => \$O{maperitive},
  'srtm:s'    => \$O{srtm},
  'smooth:s'  => \$O{smooth},
  'proxy:s'   => \$O{proxy},
  'eps:s'     => \$O{eps},
  'force-dem' => \$O{force_dem},
  'vscale:i'  => \$O{vscale},
) or syntax();

unless ( defined $O{trkfile}
  || defined $O{elefile}
  || defined $O{maperitive} ) {
  print "Please specify one or more of\n",
   "   -t track.svg      (generate track file)\n",
   "or -e elevation.svg  (generate elevation file)\n",
   "or -m base.svg       (generate Maperitive base map)\n",
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

if ( defined( my $srtm = $O{srtm} ) ) {
  die "$srtm not found" unless -d $srtm;
  print "Doing SRTM lookup for elevation data\n";
  my $lu = Geo::SRTM::Lookup->new( basedir => $srtm );
  my $done = 0;
  for my $leg (@pt) {
    my @pts = flatten($leg);
    for my $pt (@pts) {
      if ( $O{force_dem} || !defined $pt->{ele} ) {
        $pt->{ele} = $lu->lookup( $pt->{lat}, $pt->{lon} ) || 0;
        $done++;
      }
    }
  }
  print "Looked up elevation for $done points\n";
}

if ( defined( my $trkfile = $O{trkfile} ) ) {
  print "Drawing track\n";
  my $svg = make_track( \@pt );
  if ($svg) {
    print "Writing track to $trkfile\n";
    open my $of, '>', $trkfile;
    print $of $svg->xmlify;
  }
}

if ( defined( my $elefile = $O{elefile} ) ) {
  print "Drawing elevation profile\n";
  my $svg = make_profile( \@pt );
  if ($svg) {
    print "Writing elevation profile to $elefile\n";
    open my $of, '>', $elefile;
    print $of $svg->xmlify;
  }
}

if ( defined( my $maperitive = $O{maperitive} ) ) {
  my ( $minlat, $minlon, $maxlat, $maxlon ) = grow( bounds( \@pt ), 0.2 );

  if ( defined $O{map_aspect} ) {
    printf( "Fix aspect: %6.2f, %6.2f, %6.2f, %6.2f -> ",
      $minlat, $minlon, $maxlat, $maxlon );
    ( $minlat, $minlon, $maxlat, $maxlon )
     = force_aspect( $minlat, $minlon, $maxlat, $maxlon, $O{map_aspect} );
    printf( " %6.2f, %6.2f, %6.2f, %6.2f\n",
      $minlat, $minlon, $maxlat, $maxlon );
  }

  my $scpt  = "/tmp/maperitive.$$.mscript";
  my $home  = dir $O{mp_home};
  my $rules = find_rules($maperitive);
  my $exe   = file $home, MAPERITIVE;
  my $xapi  = $O{xapi_url};
  open my $of, '>', $scpt;

  if ( defined( my $proxy = $O{proxy} ) ) {
    my $puri = URI->new($proxy);
    my ( $host, $port ) = ( $puri->host, $puri->port );
    print $of <<EOT;
set-setting name=web.proxy.host value=$host
set-setting name=web.proxy.port value=$port
set-setting name=web.proxy.use-proxy value=true
EOT
  }

  print $of <<EOT;
use-ruleset location="$rules"
apply-ruleset
set-geo-bounds $minlon, $minlat, $maxlon, $maxlat
download-osm xapi-url="$xapi"
export-svg file="$maperitive" compatibility=Illustrator
EOT

  my ( $width, $height ) = get_size( $minlat, $minlon, $maxlat, $maxlon );

  my ( $vw, $vh )
   = $width > $height
   ? ( int( 1000 * $width / $height ), 1000 )
   : ( 1000, int( 1000 * $height / $width ) );

  print "Maperitive view: $vw, $vh\n";

  system $exe, "-vw=$vw", "-vh=$vh", $scpt;
  unlink $scpt;
}

sub find_rules {
  my $file = file shift;
  my $dir  = $file->parent;
  my @p    = ( file( $dir, RULES ), file $O{mp_rules} );
  for my $rules (@p) {
    print "Looking for $rules\n";
    return $rules->absolute if -e $rules;
  }
  die "No rules found";
}

sub get_size {
  my ( $minlat, $minlon, $maxlat, $maxlon ) = @_;

  my ( $minx, $miny ) = mercate( $minlat, $minlon );
  my ( $maxx, $maxy ) = mercate( $maxlat, $maxlon );

  return ( $maxx - $minx, $maxy - $miny );
}

sub force_aspect {
  my ( $minlat, $minlon, $maxlat, $maxlon, $ratio ) = @_;

  my ( $minx, $miny ) = mercate( $minlat, $minlon );
  my ( $maxx, $maxy ) = mercate( $maxlat, $maxlon );

  my $width  = $maxx - $minx;
  my $height = $maxy - $miny;

  $ratio = 1 / $ratio if $width > $height;

  my $nh = $width * $ratio;
  my $nw = $width;
  if ( $nh < $height ) {
    $nh = $height;
    $nw = $height / $ratio;
  }

  my $dw = $nw - $width;
  my $dh = $nh - $height;

  return (
    demercate( $minx - $dw / 2, $miny - $dh / 2 ),
    demercate( $maxx + $dw / 2, $maxy + $dh / 2 )
  );
}

sub grow {
  my ( $minlat, $minlon, $maxlat, $maxlon, $factor ) = @_;
  my $lats = ( $maxlat - $minlat ) * $factor;
  my $lons = ( $maxlon - $minlon ) * $factor;
  return ( $minlat - $lats, $minlon - $lons, $maxlat + $lats,
    $maxlon + $lons );
}

sub bounds {
  my $pt = shift;
  my ( $minlat, $minlon, $maxlat, $maxlon );
  for my $leg (@pt) {
    my @pts = flatten($leg);
    for my $pt (@pts) {
      $minlat = $pt->{lat} unless defined $minlat && $minlat < $pt->{lat};
      $minlon = $pt->{lon} unless defined $minlon && $minlon < $pt->{lon};
      $maxlat = $pt->{lat} unless defined $maxlat && $maxlat > $pt->{lat};
      $maxlon = $pt->{lon} unless defined $maxlon && $maxlon > $pt->{lon};
    }
  }
  return ( $minlat, $minlon, $maxlat, $maxlon );
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
    simplify_vec( $O{eps}, $xv, $yv );
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
  my $sm   = smoother( $O{smooth} );
  for my $leg (@$pt) {
    print "Plotting ", $leg->{name}, "\n";
    my ( $plat, $plon );
    my ( $xv, $yv ) = ( [], [] );
    my $left = $dist;
    my @pts  = flatten($leg);
    for my $pt (@pts) {
      $dist += $gis->distance( $plat, $plon, $pt->{lat}, $pt->{lon} )->metres
       if defined $plat;
      ( $plat, $plon ) = ( $pt->{lat}, $pt->{lon} );
      next unless defined $pt->{ele};
      push @$xv, $dist;
      push @$yv, $sm->( $pt->{ele} * $O{vscale} );
      $maxy = $pt->{ele} if $pt->{ele} > $maxy;
    }
    if (@$xv) {
      # close polygon
      push @$xv, $xv->[-1], $left;
      push @$yv, 0, 0;
      push @leg, [$xv, $yv];
    }
  }

  unless (@leg) {
    print "No elevation data found!\n";
    return;
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
    simplify_vec( $O{eps}, $xv, $yv );
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

sub smoother {
  my $decay = shift;
  my $acc   = 0;
  my $scale = 1;
  return sub {
    my $sample = shift;
    $acc   = $acc * $decay + $sample;
    $scale = $scale * $decay + 1;
    return $acc / $scale;
  };
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
  my $iw = $maxx - $minx;
  my $ih = $maxy - $miny;
  $iw ||= 1;
  $ih ||= 1;
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

sub seg_dist {
  my ( $x0, $y0, $x1, $y1, $xp, $yp ) = @_;
  my $dx = $x1 - $x0;
  my $dy = $y1 - $y0;
  return if $dx == 0 && $dy == 0;
  my $dd = sqrt( $dx * $dx + $dy * $dy );
  $dx /= $dd;
  $dy /= $dd;

  return abs( ( $xp - $x0 ) * -$dy + ( $yp - $y0 ) * $dx );
}

sub zip_points {
  my ( $xv, $yv ) = @_;
  return map { [$xv->[$_], $yv->[$_]] } 0 .. $#$xv;
}

sub unzip_points {
  my ( $pt, $xv, $yv ) = @_;
  @$xv = map { $_->[0] } @$pt;
  @$yv = map { $_->[1] } @$pt;
}

sub simplify_vec {
  my ( $eps, $xv, $yv ) = @_;
  print "Simplify $#$xv points to ";
  my @pt = simplify( $eps, zip_points( $xv, $yv ) );
  print scalar(@pt), "\n";
  unzip_points( \@pt, $xv, $yv );
}

sub simplify {
  my ( $eps, @pt ) = @_;
  my ( $max, $index );

  for my $i ( 1 .. $#pt - 1 ) {
    my $dist = seg_dist( @{ $pt[0] }, @{ $pt[-1] }, @{ $pt[$i] } );
    ( $max, $index ) = ( $dist, $i ) unless defined $max && $max > $dist;
  }

  return @pt unless defined $max;
  return ( $pt[0], $pt[-1] ) if $max <= $eps;
  my @sl1 = simplify( $eps, @pt[0 .. $index] );
  my @sl2 = simplify( $eps, @pt[$index .. $#pt] );
  pop @sl1;    # drop common point
  return ( @sl1, @sl2 );
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
