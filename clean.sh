#!/usr/bin/env bash

for a in "$@"; do
  case "$a" in
    "geo") c_geo=1 ;;
    "nobase") c_nobase=1 ;;
  esac
done

base=work/base; [ "$c_nobase" != 1 ] && [ -e "$base" ] && rm -rfv "$base"
geonames=work/geonames-db; [ "$c_geo" == 1 ] && [ -e "$geonames" ] && rm -rfv "$geonames"

