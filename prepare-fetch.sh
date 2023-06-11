#!/usr/bin/env bash
# shellcheck disable=SC2002
source vars || exit 1

[ -e "$EXTRACT_PATH" ] && rm -rf "$EXTRACT_PATH"; mkdir -vp "$EXTRACT_PATH"
[ -d "$CACHE_PATH" ] || mkdir -vp "$CACHE_PATH"

extract_pmetro() {
  file -L "$PMETRO_FILE"
  innoextract -d "$EXTRACT_PATH" "$PMETRO_FILE"
}

if ! [ -f "$PMETRO_FILE" ]; then
  for fetch_url in "${PMETRO_URL[@]}"; do
    echo "Trying '$fetch_url'"
    echo "Downloading pmetro"
    curl "$fetch_url" -vo "$PMETRO_FILE" || continue

    echo "Extracting pmetro"
    extract_pmetro || continue
    break
  done
else
  echo "Using cached pmetro"
  extract_pmetro
fi
