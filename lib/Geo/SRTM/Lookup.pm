package Geo::SRTM::Lookup;

use Moose;

our $VERSION = '0.01';

=head1 NAME

Geo::SRTM::Lookup - Lookup elevation in SRTM data

=cut

has basedir => ( is => 'ro', required => 1 );

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
