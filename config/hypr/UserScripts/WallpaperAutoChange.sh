#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# source https://wiki.archlinux.org/title/Hyprland#Using_a_script_to_change_wallpaper_every_X_minutes

# This script will randomly go through the files of a directory, setting it
# up as the wallpaper at regular intervals
#
# NOTE: this script uses bash (not POSIX shell) for the RANDOM variable

wallust_refresh=$HOME/.config/hypr/scripts/RefreshNoWaybar.sh

focused_monitor=$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}')

# Clean exit on Ctrl+C or kill signal
trap 'notify-send "Auto Wallpaper" "Stopped" -i dialog-information; exit 0' INT TERM

if [[ $# -lt 1 ]] || [[ ! -d $1   ]]; then
	echo "Usage:
	$0 <dir containing images>"
	exit 1
fi

# Edit below to control the images transition
export SWWW_TRANSITION_FPS=60
export SWWW_TRANSITION_TYPE=simple

# This controls (in seconds) when to switch to the next image
INTERVAL=1800

while true; do
	# Count images first to avoid subshell variable scope issues
	image_count=$(find "$1" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
		-o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.webp" \
		-o -iname "*.tiff" -o -iname "*.pnm" -o -iname "*.tga" \
		-o -iname "*.farbfeld" \) | wc -l)

	if [[ "$image_count" -eq 0 ]]; then
		notify-send "Auto Wallpaper" "No images found — retrying in 60s" -i dialog-warning
		sleep 60
		continue
	fi

	# Filter to image files only (skip directories, text files, etc.)
	find "$1" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
		-o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.webp" \
		-o -iname "*.tiff" -o -iname "*.pnm" -o -iname "*.tga" \
		-o -iname "*.farbfeld" \) \
		| while read -r img; do
			echo "$((RANDOM % 1000)):$img"
		done \
		| sort -n | cut -d':' -f2- \
		| while read -r img; do
			swww img -o "$focused_monitor" "$img"
			# Regenerate colors from the exact image path to avoid cache races
			"$HOME/.config/hypr/scripts/WallustSwww.sh" "$img"
			# Refresh UI components that depend on wallust output
			"$wallust_refresh"
			sleep "$INTERVAL"
			
		done
done
