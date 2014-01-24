package Geo::SRTM::Lookup;

use Moose;

use Path::Class;
use Geo::SRTM::TileCache;

our $VERSION = '0.01';

=head1 NAME

Geo::SRTM::Lookup - Lookup elevation in SRTM data

=cut

has basedir => ( is => 'ro', required => 1 );

has _cache => (
  is      => 'ro',
  default => sub { Geo::SRTM::TileCache->new( size => 5 ) }
);

#N00 N60
#S01 S56
#E000 E179
#W001 W180

sub _mk_name {
  my ( undef, $lat, $lon ) = @_;
  my $ilat = int( $lat + 90 ) - 90;
  my $ilon = int( $lon + 180 ) - 180;
  return (
    sprintf( '%s%02d%s%03d',
      ( $ilat < 0 ? 'S' : 'N' ), abs($ilat),
      ( $ilon < 0 ? 'W' : 'E' ), abs($ilon) ),
    $lat - $ilat,
    $lon - $ilon
  );
}

sub _tile_file {
  my ( $self, $name ) = @_;
  return file $self->basedir, sprintf '%s.hgt', $name;
}

sub lookup {
  my ( $self, $lat, $lon ) = @_;
  my ( $name, $olat, $olon ) = $self->_mk_name( $lat, $lon );
  my $tf   = $self->_tile_file($name);
  my $tile = $self->_cache->get($tf);
  return unless $tile;
  return $tile->lookup( $olat, $olon );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
