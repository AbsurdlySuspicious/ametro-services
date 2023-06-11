#!/usr/bin/env bash
source vars || exit 1

[[ -d "$ETAG_DIR" ]] || mkdir -v "$ETAG_DIR"
etag_file="$ETAG_DIR/pmetro_new_etag.txt"

echo "Getting pmetro etag"

for url in "${PMETRO_URL[@]}"; do
  echo "Fetching from '$url'"

  curl -Iv "$url" 2>&1 |
    tee /dev/stderr |
    perl -ne 'print if s/^< (etag: "[^"]+"|last-modified: .+$).*$/$1/i' \
      >"$etag_file"

  grep -qvP '^\s*$' <"$etag_file"; is_invalid=$?
  echo "Source: '$url'"
  echo "Fetched etag: '$(cat "$etag_file")' (validity $is_invalid)"
  [[ "$is_invalid" == 0 ]] && break
done

echo "is_invalid=$is_invalid" >>$GITHUB_OUTPUT

