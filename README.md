# CachyOS Dotfiles

System configuration and dotfiles for CachyOS, migrated from NixOS. Everything needed to restore a fully configured development + gaming workstation from a fresh CachyOS install.

## Hardware

| Component | Spec |
|-----------|------|
| **CPU** | Intel Core i5-1035G1 (4C/8T, Ice Lake) |
| **GPU** | NVIDIA GeForce MX330 2GB (PRIME offload) |
| **RAM** | 20GB DDR4 |
| **Storage** | 477GB NVMe (Btrfs) |
| **Keyboard** | BIOI SAMICE (VIA configurable, vendorId `0x8101`) |

## Software Stack

| Layer | Choice |
|-------|--------|
| **OS** | CachyOS (Arch-based) with BORE scheduler |
| **Kernel** | linux-cachyos 6.x |
| **Desktop** | KDE Plasma on Wayland |
| **Bootloader** | Limine (not GRUB, not systemd-boot) |
| **Shell** | fish + starship prompt |
| **Terminal** | Ghostty (Catppuccin Mocha theme) |
| **Input Method** | fcitx5 + bamboo (Vietnamese, VNI method) |
| **Browser** | Google Chrome |
| **Editor** | VS Code Insiders + opencode (AI terminal IDE) |

## Repository Structure

```
cachyos-dotfiles/
├── config/                         # User configs (~/.config/)
│   ├── fcitx5/                     # Vietnamese input method
│   │   ├── conf/bamboo.conf        #   Bamboo VNI settings
│   │   ├── config                  #   Hotkeys (Ctrl+Shift toggle)
│   │   └── profile                 #   IM profile
│   ├── fish/config.fish            # Fish shell (aliases, direnv, starship)
│   ├── ghostty/config              # Ghostty terminal (Catppuccin Mocha, JetBrains Mono)
│   ├── git/config                  # Git global config
│   ├── starship.toml               # Starship prompt theme
│   └── tmux/tmux.conf              # Tmux (mouse, clipboard, escape-time)
├── etc/                            # System configs (/etc/)
│   ├── default/limine              # Boot params (nmi_watchdog=0, intel_pstate=passive)
│   ├── intel-undervolt.conf        # CPU/GPU/Cache undervolt (-50mV)
│   ├── sysctl.d/99-performance.conf # Kernel tuning (vm, net, fs)
│   ├── systemd/system/             # Custom systemd services
│   │   ├── nvidia-clock-cap.service #   Lock GPU boost at 1101 MHz
│   │   ├── tailscale-autoheal.service # Restart Tailscale if unhealthy
│   │   └── tailscale-autoheal.timer   # Check every 2 minutes
│   ├── tlp.conf                    # Power management (performance-first)
│   └── udev/rules.d/
│       └── 99-via-keyboard.rules   # VIA keyboard access (BIOI SAMICE)
├── packages/                       # Package lists
│   ├── official.txt                # Pacman packages (22)
│   └── aur.txt                     # AUR packages (12)
├── scripts/
│   └── install-packages.sh         # Automated package installer
├── install.sh                      # Full system restore script
└── README.md
```

## Thermal & Performance Optimization

This system is tuned for **maximum performance** — fast and responsive over cooling.

### TLP (Power Management)
- **CPU Governor**: `performance` (AC) / `schedutil` (battery)
- **Max CPU Frequency**: 100% on both AC and battery
- **Turbo Boost**: Always enabled (`0` = never disabled)
- **Energy Performance**: `performance` on AC, `balance_performance` on battery
- **Platform Profile**: `performance`

### Intel Undervolt
- **CPU**: -50mV
- **GPU**: -50mV
- **CPU Cache**: -50mV
- Applied at boot via `intel-undervolt.service`

### NVIDIA Clock Cap
- GPU boost locked at **1101 MHz** to prevent thermal throttling
- Applied at boot via `nvidia-clock-cap.service` using `nvidia-smi`

### Kernel Boot Parameters
Set in `/etc/default/limine`, applied via `sudo limine-mkinitcpio`:
- `nmi_watchdog=0` — Disable NMI watchdog (saves power)
- `intel_pstate=passive` — Allow TLP to control CPU frequency

### Kernel Tuning (sysctl)
- `vm.swappiness=10` — Minimize swap usage
- `vm.vfs_cache_pressure=50` — Keep directory/inode caches longer
- `net.core.default_qdisc=fq` — Fair queuing scheduler
- `net.ipv4.tcp_congestion_control=bbr` — BBR congestion control
- `fs.inotify.max_user_watches=524288` — For large projects (VS Code, etc.)

## Custom Systemd Services

| Service | Type | Description |
|---------|------|-------------|
| `tailscale-autoheal.timer` | Timer (2min) | Checks Tailscale health, restarts if unhealthy |
| `tailscale-autoheal.service` | Oneshot | The actual health check + restart script |
| `nvidia-clock-cap.service` | Oneshot (boot) | Locks NVIDIA GPU boost clock at 1101 MHz |
| `intel-undervolt.service` | Oneshot (boot) | Applies CPU/GPU/Cache undervolt (system package) |
| `tlp.service` | Service | Power management daemon (system package) |
| `thermald.service` | Service | Intel thermal daemon (system package) |

## Packages

### Official (pacman) — 22 packages
Gaming: `lutris`, `heroic-games-launcher`, `gamescope`, `p7zip`, `jdk17-openjdk`
Media: `vlc`, `discord`, `noisetorch`
Productivity: `libreoffice-fresh`
Fonts: `noto-fonts`, `noto-fonts-cjk`, `noto-fonts-emoji`, `ttf-liberation`, `ttf-fira-code`, `ttf-jetbrains-mono`, `ttf-jetbrains-mono-nerd`, `otf-firamono-nerd`
Shell/Tools: `direnv`, `starship`, `tmux`, `wl-clipboard`, `gemini-cli`

### AUR — 12 packages
Apps: `google-chrome`, `visual-studio-code-insiders-bin`, `mongodb-compass`, `betterdiscordctl`, `appimagelauncher`
Gaming: `prismlauncher-offline-bin`, `the-honkers-railway-launcher-bin`, `r2modman-bin`, `gale-bin`
Music: `spotify`, `spicetify-cli`

> **Note**: `caprine-bin` is skipped — conflicts with `nodejs` (requires `nodejs-lts-iron`).

### Pre-installed by CachyOS
These packages come with CachyOS and are NOT in the package lists:
`steam`, `mangohud`, `gamemode`, `fish`, `ghostty`, `git`, `vim`, `wget`, `htop`, `fastfetch`, `lm_sensors`, `docker`, `nodejs`, `python`, `uv`, `pyenv`, `bun`, `zig`, `github-cli`, `tailscale`, `ufw`, `tlp`, `thermald`, `intel-undervolt`, `btrfs-progs`, `partitionmanager`, `lshw`, `usbutils`

## Development Environment

| Tool | Version | Notes |
|------|---------|-------|
| Node.js | 25.x | System package |
| Bun | 1.3.x | Fast JS runtime/bundler |
| Python | 3.14.x | With `uv` (fast pip) and `pyenv` |
| Zig | 0.15.x | Systems programming |
| Docker | Latest | Socket-activated, user in `docker` group |
| Git | Latest | SSH auth via `gh auth`, credential helper |
| opencode | Latest | AI terminal IDE at `~/.opencode/bin/opencode` |

### MCP Servers (configured in opencode)
- **Playwright** — Browser automation (`npx @playwright/mcp@latest`)
- **GitHub** — Repository management (`npx @modelcontextprotocol/server-github`)
- **SSH** — Remote server access (`npx ssh-mcp`)
- **Discord** — Bot integration (Python venv at `~/.local/share/opencode/mcp/mcp-discord/`)

## Gaming

| Game/Tool | Launcher | Notes |
|-----------|----------|-------|
| Steam | Native | Proton for Windows games |
| Minecraft | PrismLauncher (offline) | Cracked, worlds at `~/.local/share/PrismLauncher/` |
| Honkai: Star Rail | HSR Launcher | `the-honkers-railway-launcher-bin` |
| Other games | Lutris / Heroic | GOG, Epic, etc. |
| Performance overlay | MangoHud | `mangohud %command%` |
| Game optimizations | GameMode | `gamemoderun %command%` |
| Deck plugins | Decky Loader v3 | Plugins at `~/homebrew/` |
| Mod managers | r2modman, Gale | Thunderstore mod managers |

## Usage

### Fresh Install
```bash
# Clone the repo
git clone git@github.com:PhucTruong-ctrl/cachyos-dotfiles.git ~/cachyos-dotfiles

# Preview what will be changed (no modifications)
bash ~/cachyos-dotfiles/install.sh --dry-run

# Run the full restore
bash ~/cachyos-dotfiles/install.sh
```

### Adding Packages
```bash
# Official (pacman) package
echo "package-name" >> ~/cachyos-dotfiles/packages/official.txt

# AUR package
echo "package-name" >> ~/cachyos-dotfiles/packages/aur.txt
```

### Updating Configs
Edit the files in this repo, then copy them to their live locations:
```bash
# Example: update Ghostty config
cp ~/cachyos-dotfiles/config/ghostty/config ~/.config/ghostty/config

# Example: update TLP (requires sudo)
sudo cp ~/cachyos-dotfiles/etc/tlp.conf /etc/tlp.conf
sudo systemctl restart tlp
```

### Boot Parameters
Boot params are set in `/etc/default/limine` — **not** GRUB or systemd-boot:
```bash
sudo vim /etc/default/limine
sudo limine-mkinitcpio    # Regenerate for both kernels
# Reboot to apply
```

## Post-Install Checklist

After running `install.sh`, complete these manual steps:

- [ ] **Reboot** to apply kernel boot params (`nmi_watchdog=0`, `intel_pstate=passive`)
- [ ] **Tailscale**: `tailscale up` to connect to your network
- [ ] **GitHub CLI**: `gh auth login` (SSH method)
- [ ] **Fcitx5**: `fcitx5 -r -d` to reload input method, or log out and back in
- [ ] **Intel undervolt**: `sudo intel-undervolt read` to verify -50mV applied
- [ ] **Spicetify**: Open Spotify once, close it, then run `spicetify backup apply`
- [ ] **Spicetify extensions**: Open Spotify → Marketplace → Install `adblockify` and `hidePodcasts`
- [ ] **BetterDiscord**: `betterdiscordctl install` to inject into Discord
- [ ] **VIA keyboard**: Open [usevia.app](https://usevia.app) in Chrome to configure BIOI SAMICE

## Key Config File Locations

| Config | Repo Path | Live Path |
|--------|-----------|-----------|
| Fish shell | `config/fish/config.fish` | `~/.config/fish/config.fish` |
| Starship | `config/starship.toml` | `~/.config/starship.toml` |
| Tmux | `config/tmux/tmux.conf` | `~/.config/tmux/tmux.conf` |
| Ghostty | `config/ghostty/config` | `~/.config/ghostty/config` |
| Git | `config/git/config` | `~/.gitconfig` |
| Fcitx5 | `config/fcitx5/` | `~/.config/fcitx5/` |
| TLP | `etc/tlp.conf` | `/etc/tlp.conf` |
| Undervolt | `etc/intel-undervolt.conf` | `/etc/intel-undervolt.conf` |
| Sysctl | `etc/sysctl.d/99-performance.conf` | `/etc/sysctl.d/99-performance.conf` |
| Boot params | `etc/default/limine` | `/etc/default/limine` |
| VIA keyboard | `etc/udev/rules.d/99-via-keyboard.rules` | `/etc/udev/rules.d/99-via-keyboard.rules` |
