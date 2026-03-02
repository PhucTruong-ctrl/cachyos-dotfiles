#!/usr/bin/env bash

# screenshot.sh — Quickshell screenshot wrapper
# Usage: ./screenshot.sh {full|region|window} {save_bool} {copy_bool}

MODE=$1
SAVE=$2
COPY=$3

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/screenshot-$(date +%Y%m%d-%H%M%S).png"

GEOM=""

case $MODE in
    full)
        GEOM=""
        ;;
    region)
        GEOM=$(slurp)
        if [ -z "$GEOM" ]; then
            exit 1
        fi
        ;;
    window)
        # Get active window geometry via hyprctl
        GEOM=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        if [ "$GEOM" == "0,0 0x0" ]; then
            # Fallback if no window is active or geometry is invalid
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {full|region|window} {save_bool} {copy_bool}"
        exit 1
        ;;
esac

# Execute capture
if [ "$SAVE" = "true" ] && [ "$COPY" = "true" ]; then
    if [ -z "$GEOM" ]; then
        grim - | tee "$FILE" | wl-copy
    else
        grim -g "$GEOM" - | tee "$FILE" | wl-copy
    fi
    echo "$FILE" # Output for Quickshell log
elif [ "$SAVE" = "true" ]; then
    if [ -z "$GEOM" ]; then
        grim "$FILE"
    else
        grim -g "$GEOM" "$FILE"
    fi
    echo "$FILE"
elif [ "$COPY" = "true" ]; then
    if [ -z "$GEOM" ]; then
        grim - | wl-copy
    else
        grim -g "$GEOM" - | wl-copy
    fi
    echo "Clipboard"
fi
