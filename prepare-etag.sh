#!/usr/bin/env bash
source vars || exit 1
etag_file="$1/pmetro_new_etag.txt"

echo "Getting pmetro etag"
curl -Iv "$PMETRO_URL" 2>&1 \
  | tee /dev/stderr \
  | perl -ne 'print if s/^< etag: "([^"]+)".*$/$1/' \
  | tr -d '\n' >"$etag_file"

echo "Fetched etag: $(cat "$etag_file")"

