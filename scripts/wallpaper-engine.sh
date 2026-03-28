#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/tmp/wallpaper-engine.log"

log_info() {
    echo "[$(date)] [INFO] $*" | tee -a "$LOG_FILE" >&2
}

log_warn() {
    echo "[$(date)] [WARN] $*" | tee -a "$LOG_FILE" >&2
}

log_error() {
    echo "[$(date)] [ERROR] $*" | tee -a "$LOG_FILE" >&2
}

WALLPAPER="${1:-}"

if [[ -z "$WALLPAPER" ]]; then
    log_error "Usage: $0 <wallpaper_path>"
    exit 1
fi

if [[ ! -f "$WALLPAPER" ]]; then
    log_error "Wallpaper not found: $WALLPAPER"
    exit 1
fi

log_info "Activating wallpaper: $WALLPAPER"

if ! pgrep -x "awww-daemon" > /dev/null; then
    log_info "awww-daemon not running; starting it"
    awww-daemon &
    sleep 1
fi

pos=""
if command -v hyprctl > /dev/null; then
    pos="$(hyprctl cursorpos | tr -d ' ' || true)"
fi

if [[ -n "$pos" ]]; then
    awww img "$WALLPAPER" --transition-type grow --transition-pos "$pos" >> "$LOG_FILE" 2>&1
else
    awww img "$WALLPAPER" --transition-type grow >> "$LOG_FILE" 2>&1
fi

sync_script="$HOME/.config/quickshell/scripts/matugen-sync.sh"
if [[ ! -x "$sync_script" ]]; then
    fallback_sync_script="$HOME/cachyos-dotfiles/config/quickshell/scripts/matugen-sync.sh"
    if [[ -x "$fallback_sync_script" ]]; then
        sync_script="$fallback_sync_script"
    fi
fi

if [[ -x "$sync_script" ]]; then
    log_info "Running matugen sync via: $sync_script"
    if ! "$sync_script" "$WALLPAPER" >> "$LOG_FILE" 2>&1; then
        log_warn "matugen sync script failed"
    fi
else
    log_warn "matugen-sync.sh not found/executable; skipping color sync"
fi

log_info "Wallpaper engine complete"
