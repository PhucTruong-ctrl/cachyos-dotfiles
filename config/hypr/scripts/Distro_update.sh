#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Simple bash script to check and will try to update your system

# Local Paths
iDIR="$HOME/.config/swaync/images"

# Check for required tools (ghostty)
if ! command -v ghostty &> /dev/null; then
  notify-send -i "$iDIR/error.png" "Need Ghostty:" "Ghostty terminal not found. Please install Ghostty terminal."
  exit 1
fi

# Detect distribution and update accordingly
if command -v paru &> /dev/null || command -v yay &> /dev/null; then
  # Arch-based
  if command -v paru &> /dev/null; then
    if ghostty --title=update -e paru -Syu; then
      notify-send -i "$iDIR/ja.png" -u low 'Arch-based system' 'has been updated.'
    else
      notify-send -i "$iDIR/error.png" -u normal 'Arch-based system' 'update failed or was cancelled.'
    fi
  else
    if ghostty --title=update -e yay -Syu; then
      notify-send -i "$iDIR/ja.png" -u low 'Arch-based system' 'has been updated.'
    else
      notify-send -i "$iDIR/error.png" -u normal 'Arch-based system' 'update failed or was cancelled.'
    fi
  fi
elif command -v dnf &> /dev/null; then
  # Fedora-based
  if ghostty --title=update -e sudo dnf update --refresh -y; then
    notify-send -i "$iDIR/ja.png" -u low 'Fedora system' 'has been updated.'
  else
    notify-send -i "$iDIR/error.png" -u normal 'Fedora system' 'update failed or was cancelled.'
  fi
elif command -v apt &> /dev/null; then
  # Debian-based (Debian, Ubuntu, etc.)
  if ghostty --title=update -e bash -c "sudo apt update && sudo apt upgrade -y"; then
    notify-send -i "$iDIR/ja.png" -u low 'Debian/Ubuntu system' 'has been updated.'
  else
    notify-send -i "$iDIR/error.png" -u normal 'Debian/Ubuntu system' 'update failed or was cancelled.'
  fi
elif command -v zypper &> /dev/null; then
  # openSUSE-based
  if ghostty --title=update -e sudo zypper dup -y; then
    notify-send -i "$iDIR/ja.png" -u low 'openSUSE system' 'has been updated.'
  else
    notify-send -i "$iDIR/error.png" -u normal 'openSUSE system' 'update failed or was cancelled.'
  fi
else
  # Unsupported distro
  notify-send -i "$iDIR/error.png" -u critical "Unsupported system" "This script does not support your distribution."
  exit 1
fi
