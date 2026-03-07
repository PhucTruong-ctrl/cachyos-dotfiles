#!/bin/bash
# install-packages.sh — Install all packages from package lists
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$SCRIPT_DIR/../packages"

echo "=== Installing official packages ==="
if [ -f "$PKG_DIR/official.txt" ]; then
    mapfile -t official_packages < <(grep -v '^#' "$PKG_DIR/official.txt" | grep -v '^$')
    if [ "${#official_packages[@]}" -gt 0 ]; then
        sudo pacman -S --needed --noconfirm "${official_packages[@]}"
    fi
else
    echo "WARNING: official.txt not found"
fi

echo ""
echo "=== Installing AUR packages ==="
if [ -f "$PKG_DIR/aur.txt" ]; then
    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        [[ "$pkg" =~ ^# ]] && continue
        echo "--- Installing AUR: $pkg ---"
        paru -S --needed --noconfirm "$pkg" || echo "WARNING: Failed to install $pkg, continuing..."
    done < "$PKG_DIR/aur.txt"
else
    echo "WARNING: aur.txt not found"
fi

echo ""
echo "=== Refreshing font cache ==="
fc-cache -fv

echo ""
echo "=== Done ==="
