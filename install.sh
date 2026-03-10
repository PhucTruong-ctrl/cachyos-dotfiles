#!/bin/bash
# install.sh — Restore CachyOS system from dotfiles
# Usage: bash install.sh [--dry-run]
set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo -e "\033[1;32m==>\033[0m \033[1m$1\033[0m"; }
warn() { echo -e "\033[1;33m==> WARNING:\033[0m $1"; }
run() {
    if $DRY_RUN; then
        echo "[DRY RUN] $*"
    else
        "$@"
    fi
}

log "CachyOS Dotfiles Installer"
echo "Script dir: $SCRIPT_DIR"
$DRY_RUN && echo "*** DRY RUN MODE — no changes will be made ***"
echo ""

# --- 1. Install packages ---
log "Installing packages..."
run bash "$SCRIPT_DIR/scripts/install-packages.sh"

# --- 2. Copy system configs ---
log "Installing system configs..."
run sudo mkdir -p /usr/local/bin
run sudo cp "$SCRIPT_DIR/scripts/performance-mode.sh" /usr/local/bin/performance-mode
run sudo chmod 0755 /usr/local/bin/performance-mode
run sudo mkdir -p /etc/sudoers.d
run sudo cp "$SCRIPT_DIR/etc/sudoers.d/quickshell-performance-mode" /etc/sudoers.d/quickshell-performance-mode
run sudo chmod 0440 /etc/sudoers.d/quickshell-performance-mode
run sudo visudo -cf /etc/sudoers.d/quickshell-performance-mode
run sudo cp "$SCRIPT_DIR/etc/tlp.conf" /etc/tlp.conf
run sudo cp "$SCRIPT_DIR/etc/intel-undervolt.conf" /etc/intel-undervolt.conf
run sudo cp "$SCRIPT_DIR/etc/sysctl.d/99-performance.conf" /etc/sysctl.d/99-performance.conf
run sudo cp "$SCRIPT_DIR/etc/udev/rules.d/99-via-keyboard.rules" /etc/udev/rules.d/99-via-keyboard.rules
run sudo cp "$SCRIPT_DIR/etc/default/limine" /etc/default/limine

# --- 3. Install systemd services ---
log "Installing systemd services..."
run sudo cp "$SCRIPT_DIR/etc/systemd/system/tailscale-autoheal.service" /etc/systemd/system/
run sudo cp "$SCRIPT_DIR/etc/systemd/system/tailscale-autoheal.timer" /etc/systemd/system/
run sudo cp "$SCRIPT_DIR/etc/systemd/system/nvidia-clock-cap.service" /etc/systemd/system/
run sudo systemctl daemon-reload

# --- 4. Enable services ---
log "Enabling services..."
run sudo systemctl enable --now tlp
run sudo systemctl enable --now thermald
run sudo systemctl enable intel-undervolt
run sudo systemctl start intel-undervolt
run sudo systemctl enable --now tailscale-autoheal.timer
run sudo systemctl enable nvidia-clock-cap.service

# --- 5. Install Oh My Zsh ---
log "Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    run sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Oh My Zsh already installed, skipping."
fi

# --- 6. Symlink user configs with stow ---
log "Symlinking user configs with stow..."
if ! command -v stow >/dev/null 2>&1; then
    warn "stow not found, installing..."
    run sudo pacman -S --needed --noconfirm stow
fi
run mkdir -p "$HOME/.config"
run rm -f "$HOME/.config/mako" "$HOME/.config/waybar" "$HOME/.config/wlogout" "$HOME/.config/wofi"
run rm -f "$HOME/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
run stow --target="$HOME/.config" --restow config
run ln -sf "$SCRIPT_DIR/config/zsh/.zshrc" "$HOME/.zshrc"
run ln -sf "$SCRIPT_DIR/config/git/config" "$HOME/.gitconfig"

# --- 7. Set default shell to zsh ---
log "Setting default shell to zsh..."
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "/bin/zsh" ]; then
    run chsh -s /bin/zsh
else
    echo "Default shell is already zsh, skipping."
fi

# --- 8. User groups ---
log "Setting up user groups..."
run sudo groupadd -f plugdev
run sudo usermod -aG plugdev,input,docker "$USER"

# --- 9. Apply sysctl and regenerate boot ---
log "Applying sysctl and regenerating boot entries..."
run sudo sysctl --system
run sudo limine-mkinitcpio

# --- 10. Refresh fonts ---
log "Refreshing font cache..."
run fc-cache -fv

log "Done! Reboot recommended to apply boot parameters."
echo ""
echo "Post-install checklist:"
echo "  - Reboot to apply kernel boot params (nmi_watchdog=0, intel_pstate=active)"
echo "  - Run 'gh auth login' if GitHub CLI not authenticated"
echo "  - Run 'tailscale up' to connect to Tailscale network"
echo "  - Run 'fcitx5 -r -d' to reload input method"
echo "  - Run 'sudo intel-undervolt read' to verify undervolt"
echo "  - Open Spotify, then run 'spicetify backup apply' to activate Spicetify"
echo "  - Install adblockify & hidePodcasts from Spicetify Marketplace inside Spotify"
echo "  - Run 'betterdiscordctl install' to inject BetterDiscord"
