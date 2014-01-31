#!/bin/bash

indir="work/"
opts="--vscale 80 --srtm /data/ref/srtm/SRTMx"

find "$indir" -iname '*.tcx' | while read tcx; do
  gpx="$( echo "$tcx" | sed -e 's/\.[^.]*$//' ).gpx"
  [ "$gpx" -nt "$tcx" ] && continue
  gpsbabel -i gtrnctr -f "$tcx" -o gpx -F "$gpx"
done

find "$indir" -iname '*.gpx' | xargs -L 1 dirname | sort | uniq | while read dir; do
  track="$dir/track.svg"
  base="$dir/base.svg"
  elevation="$dir/elevation.svg"
  
  [ -e "$track" -a -e "$elevation" -a -e "$base" ] && continue
  opts=""
  [ -e "$track" ] || opts="$opts -t $track"
  [ -e "$elevation" ] || opts="$opts -e $elevation"
  [ -e "$base" ] || opts="$opts -m $base"
  perl tools/gpx2svg.pl $opts "$dir"/*.gpx
done

# vim:ts=2:sw=2:sts=2:et:ft=sh

