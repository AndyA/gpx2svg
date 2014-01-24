package Geo::SRTM::TileCache;

use Moose;
use Geo::SRTM::Tile;

=head1 NAME

Geo::SRTM::TileCache - A cache of tiles

=cut

has size => ( is => 'ro', required => 1 );

has ['_cache', '_missing'] => (
  is      => 'rw',
  isa     => 'HashRef',
  default => sub { {} },
);

sub get {
  my ( $self, $filename ) = @_;

  my $cache   = $self->_cache;
  my $missing = $self->_missing;

  return if $missing->{$filename};
  return $cache->{$filename} if exists $cache->{$filename};

  unless ( -f $filename ) {
    $missing->{$filename}++;
    return;
  }

  my @hk = keys %$cache;
  delete $cache->{ $hk[rand @hk] } if @hk >= $self->size;
  return $cache->{$filename}
   = Geo::SRTM::Tile->new( filename => $filename );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
