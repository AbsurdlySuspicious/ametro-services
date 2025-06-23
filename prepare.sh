#!/usr/bin/env bash
# shellcheck disable=SC2002
source vars || exit 1

dw_cmd_echo() {
    local prefix=$1 mode=$2 out=""
    case "$mode" in
        shell) 
            for p in "${dw_cmd[@]}"; do
                out+=$(printf '%q ' "$p")
            done ;;
        pretty)
            local buf=()
            for p in "${dw_cmd[@]}"; do
                case "$p" in
                    *' '*) buf+=("'$p'") ;;
                    *) buf+=("$p") ;;
                esac
            done
            out="${buf[*]}" ;;
        *)
            return 1 ;;
    esac
    echo "${dw_cmd_prefix_base}${prefix} ${out}"
}

_curl() {
    local dw_with=curl
    local dw_args=() head=0 out_disp=0

    case "$2" in
        --head) head=1 ;;
        --disposition) out_disp=1 ;;
    esac

    local headers=(
        'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' 
        'Accept-Language: en-US,en;q=0.9' 
        'Priority: u=0, i' 
    )

    case "$dw_with" in
        curl)
            if [[ $head == 1 ]]; then
                dw_args+=(-I)
            elif [[ $out_disp == 1 ]]; then
                dw_args+=(-O)
            else
                dw_args+=(-o "$2")
            fi
            for h in "${headers[@]}"; do
                dw_args+=(-H "$h")
            done
            dw_cmd=(
                curl 
                -A "$USER_AGENT" 
                --compressed 
                # --http1.1 
                -v "${dw_args[@]}" "$1"
            ) ;;
        wget)
            if [[ $head == 1 ]]; then
                dw_args+=(--spider)
            elif [[ $out_disp == 1 ]]; then
                dw_args+=(--content-disposition)
            else
                dw_args+=("-O${2}")
            fi
            for h in "${headers[@]}"; do
                dw_args+=("--header=$h")
            done
            dw_cmd=(
                wget
                -U "$USER_AGENT"
                --compression 
                -v "${dw_args[@]}" "$1"
            ) ;;
        *)
            return 1 ;;
    esac

    dw_cmd_prefix_base="Download command "
    dw_cmd_echo "(pretty) :" pretty
    dw_cmd_echo "(shell)  :" shell

    "${dw_cmd[@]}"
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

        _curl "$url" --head 2>&1 |
            tee /dev/stderr |
            perl -ne 'print if s/^[< ] (etag: "[^"]+"|last-modified: .+$).*$/$1/i' \
                >"$etag_file"

        grep -qvP '^\s*$' <"$etag_file"
        is_invalid=$?
        validity_text=$([[ $is_invalid == 0 ]] && echo 'OK' || echo 'INVALID')
        echo "Source: '$url'"
        echo -e "Fetched etag:\n----"
        cat "$etag_file"
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
            _curl "$fetch_url" "$PMETRO_FILE" || continue

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
        extract_pmetro cached
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
        _curl "https://download.geonames.org/export/dump/$f" --disposition
    done

    ;;
esac
