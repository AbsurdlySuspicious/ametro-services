#!/usr/bin/env bash
# shellcheck disable=SC2002
source vars || exit 1

[ -e "$EXTRACT_PATH" ] && rm -rf "$EXTRACT_PATH"; mkdir -vp "$EXTRACT_PATH"
[ -d "$CACHE_PATH" ] || mkdir -vp "$CACHE_PATH"
[ -d "$INSTALLERS_DIR" ] || mkdir -vp "$INSTALLERS_DIR"

extract_pmetro() {
  file -L "$PMETRO_FILE"
  innoextract -d "$EXTRACT_PATH" "$PMETRO_FILE"
  extract_result=$?
  cp -vl "$PMETRO_FILE" "${INSTALLERS_DIR}/downloaded.${1}.bin"
  return "$extract_result"
}

if ! [ -f "$PMETRO_FILE" ]; then
  fetch_idx=0
  for fetch_url in "${PMETRO_URL[@]}"; do
    (( fetch_idx++ ))
    echo "Trying '$fetch_url' ($fetch_idx)"
    echo "Downloading pmetro"
    curl "$fetch_url" -vo "$PMETRO_FILE" || continue

    echo "Extracting pmetro"
    extract_pmetro $fetch_idx || continue
    break
  done
else
  echo "Using cached pmetro"
  extract_pmetro
fi
