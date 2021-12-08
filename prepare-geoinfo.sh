#!/usr/bin/env bash
source vars || exit 1

FILES=(
  "cities1000.zip"
  "countryInfo.txt"
  "alternateNames.zip"
)

[ -d "$GEONAMES_PATH" ] || mkdir -vp "$GEONAMES_PATH"
cd "$GEONAMES_PATH" || exit 2
for f in "${FILES[@]}"; do
  echo "Downloading $f"
  curl -vO "https://download.geonames.org/export/dump/$f"
done
