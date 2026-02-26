#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##

# Modified version of Refresh.sh but waybar wont refresh
# Used by automatic wallpaper change
# Modified inorder to refresh rofi background, Wallust, SwayNC only

SCRIPTSDIR="$HOME/.config/hypr/scripts"
UserScripts="$HOME/.config/hypr/UserScripts"

# Define file_exists function
file_exists() {
    [ -e "$1" ]
}

# Kill already running processes
_ps=(rofi)
for _prs in "${_ps[@]}"; do
    if pidof "${_prs}" >/dev/null 2>&1; then
        pkill "${_prs}" 2>/dev/null || true
    fi
done

# quit ags & relaunch ags
#ags -q && ags &

# quit quickshell & relaunch quickshell
pkill qs && qs &

# Wallust refresh (synchronous to ensure colors are ready)
# --no-waybar-reload: skip waybar reload since this script intentionally avoids touching waybar
"${SCRIPTSDIR}/WallustSwww.sh" --no-waybar-reload
sleep 0.2

# reload swaync
swaync-client --reload-config 2>/dev/null || true

# Relaunching rainbow borders if the script exists
sleep 1
if file_exists "${UserScripts}/RainbowBorders.sh"; then
    "${UserScripts}/RainbowBorders.sh" &
    disown
fi


exit 0