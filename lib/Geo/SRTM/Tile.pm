package Geo::SRTM::Tile;

use autodie;

use Moose;

=head1 NAME

Geo::SRTM::Tile - An SRTM tile

=cut

has filename => ( is => 'ro', required => 1 );

sub file_resolution {
  my ( undef, $filename ) = @_;
  my $size = -s $filename;
  die "SRTM file must be an even number of bytes" if $size % 2;
  my $dim = sqrt( $size / 2 );
  die "SRTM file must be square" unless $dim * $dim * 2 == $size;
  return $dim - 1;
}

sub load {
  my $self = shift;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
