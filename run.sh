#!/usr/bin/env bash

CACHE_PATH="$HOME/cache"
EXTRCAT_PATH="$HOME/extract"

PMETRO_URL="https://pmetro.su/download/pMetroSetup.exe"
PMETRO_FILE=${CACHE_PATH}/pMetroSetup.exe
ETAG_FILE=${CACHE_PATH}/pmetro_etag.txt

_download_pmetro=1

if ! [ -d "$CACHE_PATH" ]; then
  mkdir -vp "$CACHE_PATH"
fi

if [ -f "$PMETRO_FILE" ]; then
  if [ -f "$ETAG_FILE" ]; then
    echo "Checking pmetro version"
    curl -Iv "$PMETRO_URL" 
  else
    echo "No etag file, but pmetro setup exists, removing"
    rm -v "$PMETRO_FILE"
  fi
else
  echo "No cached pmetro"
fi

if [ "$_download_pmetro" == 1 ]; then
  echo "Downloading pmetro"
  curl "$PMETRO_URL" -vo ${PMETRO_FILE}
fi

[ -e "$EXTRACT_PATH" ] && rm -rf "$EXTRACT_PATH"
mkdir -vp "$EXTRACT_PATH"
innoextract -d "$EXTRACT_PATH" "$PMETRO_FILE"


