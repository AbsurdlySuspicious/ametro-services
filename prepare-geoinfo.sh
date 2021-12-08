#!/usr/bin/env bash
source vars || exit 1

FILES=(
  "cities1000.zip"
  "countryInfo.txt"
  "alternateNames.zip"
)

cd "$GEONAMES_PATH" || exit 2
for f in "${FILES[@]}"; do
  curl -v "https://download.geonames.org/export/dump/$f"
done
