#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# For Searching via web browsers

# Define the path to the config file
config_file=$HOME/.config/hypr/UserConfigs/01-UserDefaults.conf
if ! command -v jq >/dev/null 2>&1; then
    notify-send -u low "Rofi Search" "jq is required for URL encoding. Please install jq."
    exit 1
fi

# Check if the config file exists
if [[ ! -f "$config_file" ]]; then
    echo "Error: Configuration file not found!"
    exit 1
fi

# Safely extract config values without eval (prevents code injection)
extract_conf_value() {
    local key="$1"
    grep -E "^\\\$?${key}\s*=" "$config_file" | head -1 | sed 's/^[^=]*=\s*//' | tr -d '"' | xargs
}

Search_Engine=$(extract_conf_value "Search_Engine")

# Check if $Search_Engine is set correctly
if [[ -z "$Search_Engine" ]]; then
    echo "Error: \$Search_Engine is not set in the configuration file!"
    exit 1
fi

# Rofi theme and message
rofi_theme="$HOME/.config/rofi/config-search.rasi"
msg='‼️ **note** ‼️ search via default web browser'

# Kill Rofi if already running before execution
if pgrep -x "rofi" >/dev/null; then
    pkill rofi
fi

# Open Rofi and pass the selected query to xdg-open for the configured search engine
query=$(printf '' | rofi -dmenu -config "$rofi_theme" -mesg "$msg")

if [[ -z "$query" ]]; then
    exit 0
fi

encoded_query=$(printf '%s' "$query" | jq -sRr @uri)
xdg-open "${Search_Engine}${encoded_query}" >/dev/null 2>&1 &
