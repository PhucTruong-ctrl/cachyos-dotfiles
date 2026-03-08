#!/usr/bin/env bash
set -euo pipefail

log_error() {
    echo "[ERROR] $*" >&2
}

usage() {
    cat >&2 <<'EOF'
Usage: wallpaper-thumbnail.sh (--file <path> | --directory <path>) [--size normal|large|x-large|xx-large]
EOF
}

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" > /dev/null; then
        log_error "$command_name is not installed"
        exit 1
    fi
}

size_to_pixels() {
    case "$1" in
        normal) printf '%s\n' 128 ;;
        large) printf '%s\n' 256 ;;
        x-large) printf '%s\n' 512 ;;
        xx-large) printf '%s\n' 1024 ;;
        *)
            log_error "Unsupported thumbnail size: $1"
            usage
            exit 1
            ;;
    esac
}

canonical_uri() {
    local input_path="$1"

    INPUT_PATH="$input_path" python3 - <<'PY'
from pathlib import Path
from urllib.parse import quote
import os

path = str(Path(os.environ["INPUT_PATH"]).resolve())
print("file://" + quote(path, safe='/-._~'))
PY
}

thumbnail_hash() {
    local input_path="$1"

    INPUT_PATH="$input_path" python3 - <<'PY'
from pathlib import Path
from urllib.parse import quote
import hashlib
import os

path = str(Path(os.environ["INPUT_PATH"]).resolve())
canonical = "file://" + quote(path, safe='/-._~')
print(hashlib.md5(canonical.encode()).hexdigest())
PY
}

generate_thumbnail() {
    local input_path="$1"
    local size_name="$2"
    local pixel_size output_dir output_path hash_value

    if [[ ! -f "$input_path" ]]; then
        log_error "Image not found: $input_path"
        exit 1
    fi

    pixel_size="$(size_to_pixels "$size_name")"
    output_dir="$HOME/.cache/thumbnails/$size_name"
    hash_value="$(thumbnail_hash "$input_path")"
    output_path="$output_dir/$hash_value.png"

    mkdir -p "$output_dir"

    if [[ -f "$output_path" ]]; then
        return 0
    fi

    magick "$input_path" -auto-orient -thumbnail "${pixel_size}x${pixel_size}>" "$output_path"
}

generate_directory_thumbnails() {
    local input_dir="$1"
    local size_name="$2"
    local image_path

    if [[ ! -d "$input_dir" ]]; then
        log_error "Directory not found: $input_dir"
        exit 1
    fi

    shopt -s nullglob nocaseglob
    for image_path in "$input_dir"/*.jpg "$input_dir"/*.jpeg "$input_dir"/*.png "$input_dir"/*.webp; do
        generate_thumbnail "$image_path" "$size_name"
    done
    shopt -u nullglob nocaseglob
}

main() {
    local file_path=""
    local directory_path=""
    local size_name="large"

    require_command magick
    require_command python3

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file)
                [[ $# -ge 2 ]] || {
                    usage
                    exit 1
                }
                file_path="$2"
                shift 2
                ;;
            --directory)
                [[ $# -ge 2 ]] || {
                    usage
                    exit 1
                }
                directory_path="$2"
                shift 2
                ;;
            --size)
                [[ $# -ge 2 ]] || {
                    usage
                    exit 1
                }
                size_name="$2"
                shift 2
                ;;
            *)
                usage
                exit 1
                ;;
        esac
    done

    size_to_pixels "$size_name" > /dev/null

    if [[ -n "$file_path" && -n "$directory_path" ]]; then
        log_error "Choose either --file or --directory"
        usage
        exit 1
    fi

    if [[ -n "$file_path" ]]; then
        generate_thumbnail "$file_path" "$size_name"
        return 0
    fi

    if [[ -n "$directory_path" ]]; then
        generate_directory_thumbnails "$directory_path" "$size_name"
        return 0
    fi

    log_error "Missing --file or --directory"
    usage
    exit 1
}

main "$@"
