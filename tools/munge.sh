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

  t=false; e=false; m=false

  for gpx in "$dir/"*.gpx; do
    [ "$gpx" -nt "$track" ]     && t=true
    [ "$gpx" -nt "$elevation" ] && e=true
    [ "$gpx" -nt "$base" ]      && m=true
  done
  
  opts=""
  $t && opts="$opts -t $track"
  $e && opts="$opts -e $elevation"
  $m && opts="$opts -m $base"

  $t || $e || $m || continue

  set -x
  perl tools/gpx2svg.pl $opts "$dir"/*.gpx
  set +x
done

# vim:ts=2:sw=2:sts=2:et:ft=sh

