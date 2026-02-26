#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Script for Random Wallpaper ( CTRL ALT W)

PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallDIR="$PICTURES_DIR/wallpapers"
SCRIPTSDIR="$HOME/.config/hypr/scripts"

focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

PICS=($(find -L "${wallDIR}" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.pnm" -o -name "*.tga" -o -name "*.tiff" -o -name "*.webp" -o -name "*.bmp" -o -name "*.farbfeld" -o -name "*.gif" \)))

# Guard against empty wallpapers directory (prevents division by zero)
if [[ ${#PICS[@]} -eq 0 ]]; then
  notify-send "Random Wallpaper" "No wallpapers found in $wallDIR" -i dialog-warning
  exit 1
fi

RANDOMPICS=${PICS[ $RANDOM % ${#PICS[@]} ]}


# Transition config
FPS=30
TYPE="random"
DURATION=1
BEZIER=".43,1.19,1,.4"
SWWW_PARAMS="--transition-fps $FPS --transition-type $TYPE --transition-duration $DURATION --transition-bezier $BEZIER"


# shellcheck disable=SC2086
swww query || swww-daemon --format xrgb && swww img -o "$focused_monitor" "${RANDOMPICS}" $SWWW_PARAMS

"$SCRIPTSDIR/WallustSwww.sh"
sleep 2
# WallustSwww.sh already reloads waybar colors — only refresh non-waybar services
"$SCRIPTSDIR/RefreshNoWaybar.sh"

