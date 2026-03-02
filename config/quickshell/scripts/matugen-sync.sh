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

if ! command -v matugen > /dev/null; then
    log_error "matugen is not installed"
    exit 1
fi

if ! command -v jq > /dev/null; then
    log_error "jq is not installed"
    exit 1
fi

cache_dir="$HOME/.cache/matugen"
colors_file="$cache_dir/colors.json"
tmp_file="$(mktemp "$cache_dir/colors.XXXXXX.json" 2>/dev/null || true)"

mkdir -p "$cache_dir"

if [[ -z "$tmp_file" ]]; then
    tmp_file="$cache_dir/colors.tmp.json"
fi

log_info "Generating Matugen palette from: $wallpaper"

matugen image "$wallpaper" --json hex \
    | jq '{
        colors: {
            primary: .colors.dark.primary,
            onPrimary: .colors.dark.on_primary,
            background: .colors.dark.background,
            onBackground: .colors.dark.on_background,
            surface: .colors.dark.surface,
            onSurface: .colors.dark.on_surface,
            surfaceVariant: .colors.dark.surface_variant,
            onSurfaceVariant: .colors.dark.on_surface_variant,
            error: .colors.dark.error
        }
    }' > "$tmp_file"

mv "$tmp_file" "$colors_file"
log_info "Wrote $colors_file"

if command -v qs > /dev/null; then
    if qs ipc call global-state reload-colors > /dev/null 2>&1; then
        log_info "Triggered Quickshell color reload"
    else
        log_warn "Quickshell IPC reload failed (shell may not be running)"
    fi
else
    log_warn "qs not found; skipped Quickshell color reload"
fi
