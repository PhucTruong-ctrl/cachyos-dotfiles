#!/usr/bin/env bash
# sys-screenshot.sh
# End-4 style screenshot workflow for Hyprland + Quickshell
# Dependencies: grim, slurp, swappy, wl-clipboard, notify-send

# Settings
DIR="$HOME/Pictures/Screenshots"
IMG_NAME="screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
SAVE_PATH="$DIR/$IMG_NAME"

# Ensure the directory exists
mkdir -p "$DIR"

send_notification() {
    local file="$1"
    local title="$2"
    local message="$3"
    
    if [ -f "$file" ]; then
        notify-send -a "Screenshot" -i "$file" "$title" "$message"
    else
        notify-send -a "Screenshot" "$title" "$message"
    fi
}

case "$1" in
    full)
        grim "$SAVE_PATH" && wl-copy < "$SAVE_PATH"
        send_notification "$SAVE_PATH" "Full Screenshot" "Saved to Pictures and copied to clipboard."
        ;;
    area)
        grim -g "$(slurp)" "$SAVE_PATH" && wl-copy < "$SAVE_PATH"
        send_notification "$SAVE_PATH" "Area Screenshot" "Saved to Pictures and copied to clipboard."
        ;;
    edit)
        grim -g "$(slurp)" - | swappy -f - -o "$SAVE_PATH" && wl-copy < "$SAVE_PATH"
        send_notification "$SAVE_PATH" "Screenshot Edited" "Saved to Pictures and copied to clipboard."
        ;;
    *)
        echo "Usage: $0 {full|area|edit}"
        exit 1
        ;;
esac
