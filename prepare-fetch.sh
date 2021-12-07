#!/usr/bin/env bash
source vars || exit 1

[ -e "$EXTRACT_PATH" ] && rm -rf "$EXTRACT_PATH"; mkdir -vp "$EXTRACT_PATH"
[ -d "$CACHE_PATH" ] || mkdir -vp "$CACHE_PATH"


if ! [ -f "$PMETRO_FILE" ]; then
  echo "Downloading pmetro"
  curl "$PMETRO_URL" -vo "$PMETRO_FILE"
else
  echo "Using cached pmetro"
fi

echo "Extracting pmetro"
innoextract -d "$EXTRACT_PATH" "$PMETRO_FILE"


