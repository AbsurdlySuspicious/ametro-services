#!/usr/bin/env bash
base=work/base; [ -e "$base" ] && rm -rfv "$base"
geonames=work/geonames/geonames.db; [ -e "$geonames" ] && rm -v "$geonames"

