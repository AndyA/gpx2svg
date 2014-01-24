package Geo::SRTM::Tile;

use autodie;

use Moose;

=head1 NAME

Geo::SRTM::Tile - An SRTM tile

=cut

has filename   => ( is => 'ro', required => 1 );
has resolution => ( is => 'ro', writer   => '_set_resolution', );
has _fh        => ( is => 'ro', lazy     => 1, builder => '_open' );

sub file_resolution {
  my ( undef, $filename ) = @_;
  my $size = -s $filename;
  die "SRTM file must be an even number of bytes" if $size % 2;
  my $dim = sqrt( $size / 2 );
  die "SRTM file must be square" unless $dim * $dim * 2 == $size;
  return $dim - 1;
}

sub BUILD {
  my $self = shift;
  $self->_set_resolution( $self->file_resolution( $self->filename ) );
}

sub _size { shift->resolution + 1 }

sub _open {
  my $self = shift;
  open my $fh, '<', $self->filename;
  $fh->binmode;
  return $fh;
}

sub _lookup {
  my ( $self, $lat, $lon ) = @_;
  my $res  = $self->resolution;
  my $size = $self->_size;
  my $y    = int( ( $lat - int $lat ) * $res );
  my $x    = int( ( $lon - int $lon ) * $res );
  my $fh   = $self->_fh;
  my $pos  = ( ( $res - $y ) * $size + $x ) * 2;
  #  printf( "%6.2f %6.2f %5d %5d %10d\n", $lat, $lon, $x, $y, $pos );
  my $lim = $size * $size * 2;
  if ( $pos < 0 || $pos >= $lim ) {
    die "*** x: $x, y: $y, res: $res, size: $size, pos: $pos, lim: $lim\n";
  }
  $fh->seek( $pos, 'SEEK_SET' );
  $fh->read( my $data, 2 );
  return unpack 'n', $data;
}

sub lookup {
  my ( $self, $lat, $lon ) = @_;
  my $datum = $self->_lookup( $lat, $lon );
  $datum -= 65536 if $datum >= 32768;    # sign extend
  return if $datum <= -32767;            # missing
  return $datum;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
