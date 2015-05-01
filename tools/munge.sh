#!/bin/bash

indir="work/"

find "$indir" -iname '*.tcx' | while read tcx; do
  gpx="$( echo "$tcx" | sed -e 's/\.[^.]*$//' ).gpx"
  [ "$gpx" -nt "$tcx" ] && continue
  gpsbabel -i gtrnctr -f "$tcx" -o gpx -F "$gpx"
done

find "$indir" -iname '*.gpx' | xargs -L 1 dirname | sort | uniq | while read dir; do
  opts="--vscale 80 --srtm /nfs/data/ref/srtm/SRTMx"
  track="$dir/track.svg"
  base="$dir/base.svg"
  elevation="$dir/elevation.svg"
  fine="$dir/elefine.svg"

  t=false; e=false; m=false; f=false

  for gpx in "$dir/"*.gpx; do
    [ "$gpx" -nt "$track" ]     && t=true
    [ "$gpx" -nt "$elevation" ] && e=true
    [ "$gpx" -nt "$base" ]      && m=true
    [ "$gpx" -nt "$fine" ]      && f=true
  done
  
  if $f; then
    set -x
    perl tools/gpx2svg.pl --eps 0.1 $opts -e $fine "$dir"/*.gpx
    set +x
  fi

  $t || $e || $m || continue

  $t && opts="$opts -t $track"
  $e && opts="$opts -e $elevation"
  $m && opts="$opts -m $base"

  set -x
  perl tools/gpx2svg.pl $opts "$dir"/*.gpx
  set +x
done

# vim:ts=2:sw=2:sts=2:et:ft=sh

