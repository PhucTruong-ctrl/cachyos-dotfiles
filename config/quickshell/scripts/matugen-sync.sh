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
            primary: .colors.primary.dark,
            onPrimary: .colors.on_primary.dark,
            background: .colors.background.dark,
            onBackground: .colors.on_background.dark,
            surface: .colors.surface.dark,
            onSurface: .colors.on_surface.dark,
            surfaceVariant: .colors.surface_variant.dark,
            onSurfaceVariant: .colors.on_surface_variant.dark,
            surfaceContainer: (.colors.surface_container.dark // .colors.surface_variant.dark),
            surfaceContainerLow: (.colors.surface_container_low.dark // .colors.surface.dark),
            error: .colors.error.dark
        }
    }' > "$tmp_file"

mv "$tmp_file" "$colors_file"
log_info "Wrote $colors_file"

# Generate GTK CSS overrides from the new colors.json
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gtk_gen="$script_dir/gtk-theme-gen.sh"
if [[ -x "$gtk_gen" ]]; then
    log_info "Generating GTK CSS overrides..."
    "$gtk_gen" || log_warn "gtk-theme-gen.sh failed (non-fatal)"
else
    log_warn "gtk-theme-gen.sh not found or not executable: $gtk_gen"
fi

# Generate hyprlock color variables from the new colors.json
hyprlock_gen="$script_dir/hyprlock-colors.sh"
if [[ -x "$hyprlock_gen" ]]; then
    log_info "Generating hyprlock color variables..."
    "$hyprlock_gen" || log_warn "hyprlock-colors.sh failed (non-fatal)"
else
    log_warn "hyprlock-colors.sh not found or not executable: $hyprlock_gen"
fi

# No IPC needed — GlobalState.qml uses a FileWatcher on colors.json
# which detects this write and triggers reloadColors() automatically.
log_info "FileWatcher will pick up the change automatically"
