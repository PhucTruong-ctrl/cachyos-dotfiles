#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Scripts for refreshing ags, waybar, rofi, swaync, wallust

SCRIPTSDIR="$HOME/.config/hypr/scripts"
UserScripts="$HOME/.config/hypr/UserScripts"

# Define file_exists function
file_exists() {
  [ -e "$1" ]
}

# Kill cava processes BEFORE waybar to prevent orphaned zombies
# (waybar spawns cava via custom modules; if we kill waybar without
#  killing cava first, the old cava processes keep running forever)
pkill -x cava 2>/dev/null || true
sleep 0.2

# Kill already running processes
_ps=(waybar rofi swaync ags)
for _prs in "${_ps[@]}"; do
  if pidof "${_prs}" >/dev/null 2>&1; then
    pkill "${_prs}" 2>/dev/null || true
  fi
done

# added since wallust sometimes not applying
killall -SIGUSR2 waybar 2>/dev/null || true
# Added sleep for GameMode causing multiple waybar
sleep 0.1

# quit ags & relaunch ags
#ags -q && ags &

# quit quickshell & relaunch quickshell
pkill qs && qs &

# some process to kill
for _pid in $(pidof waybar rofi swaync ags swaybg 2>/dev/null); do
  kill -SIGUSR1 "$_pid" 2>/dev/null || true
  sleep 0.1
done

#Restart waybar
sleep 0.1
waybar &
disown

# relaunch swaync
sleep 0.3
swaync >/dev/null 2>&1 &
disown
# reload swaync
swaync-client --reload-config 2>/dev/null || true

# Relaunching rainbow borders if the script exists
sleep 1
if file_exists "${UserScripts}/RainbowBorders.sh"; then
  "${UserScripts}/RainbowBorders.sh" &
  disown
fi

exit 0
