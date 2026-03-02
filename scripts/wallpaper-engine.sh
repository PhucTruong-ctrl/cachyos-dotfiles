#!/usr/bin/env bash

LOG_FILE="/tmp/wallpaper-engine.log"
echo "[$(date)] ========================" >> "$LOG_FILE"
WALLPAPER="$1"
echo "[$(date)] Script called with: $WALLPAPER" >> "$LOG_FILE"

if [ -z "$WALLPAPER" ]; then
    echo "[$(date)] Usage: $0 <wallpaper_path>" >> "$LOG_FILE"
    exit 1
fi

# Ensure swww-daemon is running
if ! pgrep -x "swww-daemon" > /dev/null; then
    echo "[$(date)] swww-daemon not running. Starting it..." >> "$LOG_FILE"
    swww-daemon &
    sleep 1
fi

POS=$(hyprctl cursorpos | tr -d ' ')
echo "[$(date)] Cursor position: $POS" >> "$LOG_FILE"

echo "[$(date)] Running swww..." >> "$LOG_FILE"
swww img "$WALLPAPER" --transition-type grow --transition-pos "$POS" >> "$LOG_FILE" 2>&1

echo "[$(date)] Running matugen..." >> "$LOG_FILE"
if command -v matugen &> /dev/null; then
    matugen image "$WALLPAPER" >> "$LOG_FILE" 2>&1
else
    echo "[$(date)] matugen not found, skipping." >> "$LOG_FILE"
fi

echo "[$(date)] Done." >> "$LOG_FILE"
