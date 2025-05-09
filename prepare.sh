#!/usr/bin/env bash
# shellcheck disable=SC2002
source vars || exit 1

_curl() {
    curl \
    -A "$USER_AGENT" \
    --compressed \
    -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' \
    -H 'Accept-Language: en-US,en;q=0.9' \
    "$@"
}

command=$1
shift

case "$command" in

prepare-etag)

    [[ -d "$ETAG_DIR" ]] || mkdir -v "$ETAG_DIR"
    etag_file="$ETAG_DIR/pmetro_new_etag.txt"

    echo "Getting pmetro etag"

    for url in "${PMETRO_URL[@]}"; do
        echo "Fetching from '$url'"

        _curl -Iv "$url" 2>&1 |
            tee /dev/stderr |
            perl -ne 'print if s/^< (etag: "[^"]+"|last-modified: .+$).*$/$1/i' \
                >"$etag_file"

        grep -qvP '^\s*$' <"$etag_file"
        is_invalid=$?
        validity_text=$([[ $is_invalid == 0 ]] && echo 'OK' || echo 'INVALID')
        echo "Source: '$url'"
        echo -e "Fetched etag:\n----"
        echo -e "----\nValidity: $is_invalid [$validity_text]"
        [[ $is_invalid == 0 ]] && break
    done

    echo "is_invalid=$is_invalid" >>$GITHUB_OUTPUT

    ;;

prepare-fetch)

    [ -e "$EXTRACT_PATH" ] && rm -rf "$EXTRACT_PATH"
    mkdir -vp "$EXTRACT_PATH"
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
        success=0
        for fetch_url in "${PMETRO_URL[@]}"; do
            ((fetch_idx++))
            echo "Trying '$fetch_url' ($fetch_idx)"
            echo "Downloading pmetro"
            _curl "$fetch_url" -vo "$PMETRO_FILE" || continue

            echo "Extracting pmetro"
            extract_pmetro $fetch_idx || continue
            success=1
            break
        done
        if [[ $success != 1 ]]; then
          echo "Failed to download or extract pmetro"
          exit 1
        fi
    else
        echo "Using cached pmetro"
        extract_pmetro
    fi

    ;;

prepare-geoinfo)

    FILES=(
        "cities1000.zip"
        "countryInfo.txt"
        "alternateNames.zip"
    )

    [ -d "$GEONAMES_PATH" ] || mkdir -vp "$GEONAMES_PATH"
    cd "$GEONAMES_PATH" || exit 2
    for f in "${FILES[@]}"; do
        echo "Downloading $f"
        _curl -vO "https://download.geonames.org/export/dump/$f"
    done

    ;;
esac
