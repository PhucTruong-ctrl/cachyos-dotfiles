# CachyOS Dotfiles

System configuration and dotfiles for CachyOS (migrated from NixOS).

## Hardware

- **CPU**: Intel i5-1035G1
- **GPU**: NVIDIA MX330 2GB (PRIME offload)
- **RAM**: 20GB
- **Storage**: 477GB NVMe (Btrfs)
- **Keyboard**: BIOI SAMICE (VIA configurable)

## System

- **OS**: CachyOS (Arch-based) with BORE scheduler
- **Desktop**: KDE Plasma on Wayland
- **Bootloader**: Limine
- **Shell**: fish + starship prompt
- **Input Method**: fcitx5 + bamboo (Vietnamese)

## Structure

```
cachyos-dotfiles/
├── etc/                    # System config backups (/etc/ files)
│   ├── default/            # Limine bootloader config
│   ├── intel-undervolt.conf
│   ├── sysctl.d/           # Kernel parameters
│   ├── systemd/system/     # Custom systemd services
│   ├── tlp.conf            # Power management
│   └── udev/rules.d/       # Device rules (VIA keyboard)
├── config/                 # User config files (~/.config/)
│   ├── fish/               # Fish shell config
│   ├── fcitx5/             # Input method config
│   └── starship.toml       # Starship prompt
├── packages/               # Package lists
│   ├── official.txt        # Pacman packages
│   └── aur.txt             # AUR packages
├── scripts/                # Setup and maintenance scripts
│   └── install-packages.sh
└── install.sh              # Full system restore script
```

## Thermal Optimization

- **TLP**: CPU governor powersave, max perf 70% AC / 50% BAT
- **Intel Undervolt**: -50mV on CPU/GPU/Cache
- **Kernel Params**: `nmi_watchdog=0 intel_pstate=passive`
- **NVIDIA Clock Cap**: Max 1101 MHz boost
- **Thermald**: Enabled

## Custom Services

- `tailscale-autoheal.timer` — Restarts Tailscale every 2min if unhealthy
- `nvidia-clock-cap.service` — Caps GPU boost clocks on boot

## Usage

```bash
# Install all packages
bash scripts/install-packages.sh

# Full system restore (copies configs, enables services)
bash install.sh
```
