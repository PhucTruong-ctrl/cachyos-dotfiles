#!/usr/bin/env bash

WALLPAPER="$1"

if [ -z "$WALLPAPER" ]; then
    echo "Usage: $0 <wallpaper_path>"
    exit 1
fi

swww img "$WALLPAPER" --transition-type grow --transition-pos "$(hyprctl cursorpos)"
matugen image "$WALLPAPER"
