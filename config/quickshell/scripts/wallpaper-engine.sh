#!/usr/bin/env bash
set -euo pipefail

log_info() {
    echo "[INFO] $*" >&2
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

wallpaper="${1:-}"

if [[ -z "$wallpaper" ]]; then
    log_error "Usage: $0 <wallpaper_path>"
    exit 1
fi

if [[ ! -f "$wallpaper" ]]; then
    log_error "Wallpaper not found: $wallpaper"
    exit 1
fi

log_info "Activating wallpaper: $wallpaper"

if ! pgrep -x "swww-daemon" > /dev/null; then
    log_info "swww-daemon not running; starting it"
    swww-daemon &
    sleep 1
fi

pos=""
if command -v hyprctl > /dev/null; then
    pos="$(hyprctl cursorpos | tr -d ' ' || true)"
fi

if [[ -n "$pos" ]]; then
    swww img "$wallpaper" --transition-type grow --transition-pos "$pos"
else
    swww img "$wallpaper" --transition-type grow
fi

# Persist the wallpaper path so Quickshell can restore it on restart
cache_dir="$HOME/.cache/quickshell"
mkdir -p "$cache_dir"
printf '%s' "$wallpaper" > "$cache_dir/current_wallpaper"
log_info "Saved wallpaper path to $cache_dir/current_wallpaper"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sync_script="$script_dir/matugen-sync.sh"
thumbnail_script="$script_dir/wallpaper-thumbnail.sh"

if [[ -x "$sync_script" ]]; then
    log_info "Running matugen sync via: $sync_script"
    if ! "$sync_script" "$wallpaper"; then
        log_warn "matugen sync script failed"
    fi
else
    log_warn "matugen-sync.sh not found/executable; skipping color sync"
fi

if [[ -x "$thumbnail_script" ]]; then
    log_info "Generating wallpaper thumbnail in background"
    ("$thumbnail_script" --file "$wallpaper" > /dev/null 2>&1 || true) &
else
    log_warn "wallpaper-thumbnail.sh not found/executable; skipping thumbnail generation"
fi

log_info "Wallpaper engine complete"
