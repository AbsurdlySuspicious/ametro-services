#!/usr/bin/env bash
# shellcheck disable=SC2002
source vars || exit 1

[ -e "$EXTRACT_PATH" ] && rm -rf "$EXTRACT_PATH"; mkdir -vp "$EXTRACT_PATH"
[ -d "$CACHE_PATH" ] || mkdir -vp "$CACHE_PATH"
fetch_url=$(cat "$ETAG_DIR/pmetro_url.txt" | tr -d '\n')

if ! [ -f "$PMETRO_FILE" ]; then
  echo "Downloading pmetro"
  curl "$fetch_url" -vo "$PMETRO_FILE"
else
  echo "Using cached pmetro"
fi

echo "Extracting pmetro"
innoextract -d "$EXTRACT_PATH" "$PMETRO_FILE"


