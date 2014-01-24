package Geo::SRTM::Tile;

use autodie;

use Moose;

=head1 NAME

Geo::SRTM::Tile - An SRTM tile

=cut

has filename   => ( is => 'ro', required => 1 );
has resolution => ( is => 'ro', writer   => '_set_resolution', );
has _data      => ( is => 'ro', lazy     => 1, builder => '_load' );

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

sub _load {
  my $self = shift;
  open my $fh, '<', $self->filename;
  $fh->binmode;
  my $row  = $self->_size;
  my $size = $row * $row * 2;
  my $got  = read $fh, my ($data), $size;
  die "I/O error ($got, $size)" unless $got == $size;
  return $data;
}

sub _lookup {
  my ( $self, $lat, $lon ) = @_;
  my $res  = $self->resolution;
  my $size = $self->_size;
  my $x    = int( ( $lat - int $lat ) * $res );
  my $y    = int( ( $lon - int $lon ) * $res );
  return unpack 'n', substr $self->_data, ( $y * $size + $x ) * 2, 2;
}

sub lookup {
  my ( $self, $lat, $lon ) = @_;
  my $datum = $self->_lookup( $lat, $lon );
  $datum -= 65536 if $datum >= 32768;    # sign extend
  return if $datum == -32767;            # missing
  return $datum;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
