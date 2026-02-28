# CachyOS Dotfiles

Dotfiles and system restore scripts for a CachyOS laptop running Hyprland.

Current direction: this repo now tracks a **CachyOS-default Hyprland base** (from `cachyos-hyprland-settings`) plus a few personal overrides, so ricing can be done cleanly from a known baseline.

## What This Repo Manages

- User configs under `config/` (deployed to `~/.config` with GNU Stow)
- System configs under `etc/` (deployed with `sudo cp` via `install.sh`)
- Package manifests under `packages/` (`official.txt`, `aur.txt`)
- Provisioning scripts under `scripts/` and root `install.sh`

## Default Stack (Current)

- **WM/Compositor**: Hyprland
- **Bar**: Waybar (CachyOS default config)
- **Launcher**: Wofi (CachyOS default launcher)
- **Notifications**: Mako
- **Locker**: Swaylock
- **Terminal**: Ghostty (personal preference)
- **Shell**: Zsh + Oh My Zsh + Starship
- **Input Method**: Fcitx5 + Bamboo

## Does CachyOS Provide Defaults?

Yes. CachyOS ships desktop defaults through packages, including:

- `cachyos-hyprland-settings`
- `cachyos-settings`

For Hyprland, defaults are provided in `/etc/skel/.config` (Hyprland, Waybar, Wofi, Wlogout, Mako, Swaylock, etc.).

## Repository Layout

```text
cachyos-dotfiles/
├── config/                  # User-level configs (stowed into ~/.config)
│   ├── fastfetch/
│   ├── fcitx5/
│   ├── fish/
│   ├── ghostty/
│   ├── git/
│   ├── hypr/
│   ├── mako/
│   ├── starship.toml
│   ├── swaylock/
│   ├── tmux/
│   ├── waybar/
│   ├── wlogout/
│   ├── wofi/
│   ├── zellij/
│   └── zsh/
├── etc/                     # System-level config files for /etc
├── packages/                # official.txt + aur.txt manifests
├── scripts/                 # helper scripts
├── install.sh               # main install/restore script
└── README.md
```

## Config Directory Reference

This is what each top-level item in `config/` is for:

- `config/fastfetch/` - 
- `config/fcitx5/` - input method engine settings; keyboard/input switching and Bamboo Vietnamese typing behavior.
- `config/ghostty/` - Ghostty terminal emulator settings (font, theme, behavior); your preferred terminal profile.
- `config/git/` - Git client configuration used for `~/.gitconfig` (identity, defaults, pager/editor options).
- `config/hypr/` - Hyprland compositor config; window manager behavior, keybinds, monitor layout, startup apps, rules.
- `config/mako/` - Mako notification daemon config (position, timeout, style of notifications).
- `config/starship.toml` - prompt theme and module configuration for Starship shell prompt.
- `config/swaylock/` - Swaylock lockscreen settings (visual + auth prompt behavior).
- `config/tmux/` - Tmux terminal multiplexer settings (prefix, panes, status line, keymaps).
- `config/waybar/` - Waybar top/bottom panel settings (modules, order, scripts, CSS styling).
- `config/wlogout/` - logout/power menu layout and theme.
- `config/wofi/` - Wofi launcher config + style (app launcher behavior and look).
- `config/zellij/` - Zellij terminal workspace/multiplexer defaults.
- `config/zsh/` - Zsh shell profile (`.zshrc`) and shell behavior defaults.

Quick rule of thumb:

- **Desktop/session behavior**: `hypr`, `waybar`, `wofi`, `wlogout`, `mako`, `swaylock`
- **Terminal/shell workflow**: `ghostty`, `tmux`, `zellij`, `zsh`, `starship.toml`
- **CLI/tools behavior**: `git`, `fastfetch`, `fcitx5`

## Hyprland Notes

Main file: `config/hypr/hyprland.conf`

Modular includes live in `config/hypr/config/`:

- `monitor.conf` - monitor rules and scaling
- `keybinds.conf` - keybindings
- `defaults.conf` - app variables (`$terminal`, `$applauncher`, `$filemanager`)
- `autostart.conf` - startup services/apps
- `windowrules.conf` - per-app rules
- `input.conf`, `decorations.conf`, `animations.conf`, `colors.conf`, `environment.conf`, `variables.conf`

Current keybind baseline includes:

- `SUPER+ENTER` terminal
- `SUPER+E` file manager
- `SUPER+Q` close active window
- `SUPER+D` launcher
- `SUPER+1..5` switch workspaces

Current monitor override example (laptop panel):

```ini
monitor = eDP-1, 1920x1080@60, 0x0, 1.5
```

## Symlink Model (Stow)

This repo uses GNU Stow for user configs.

- Target directory: `~/.config`
- Command used by installer: `stow --target="$HOME/.config" --restow config`
- Additional direct symlinks:
  - `config/zsh/.zshrc` -> `~/.zshrc`
  - `config/git/config` -> `~/.gitconfig`

Check symlink status:

```bash
for item in hypr waybar wofi fastfetch; do
  ls -ld "$HOME/.config/$item"
done
```

## Install / Restore

```bash
git clone git@github.com:PhucTruong-ctrl/cachyos-dotfiles.git ~/cachyos-dotfiles
cd ~/cachyos-dotfiles

# Preview
bash install.sh --dry-run

# Apply
bash install.sh
```

`install.sh` will:

- install packages from manifests
- copy tracked `/etc` files
- install/enable required services
- stow `config/` into `~/.config`
- set zsh as default shell

## Package Manifests

- Official packages: `packages/official.txt`
- AUR packages: `packages/aur.txt`

Edit the manifests directly, then run:

```bash
bash scripts/install-packages.sh
```

## Performance / System Tuning (Tracked)

Managed under `etc/`:

- `etc/intel-undervolt.conf`
- `etc/tlp.conf`
- `etc/sysctl.d/99-performance.conf`
- `etc/default/limine`
- `etc/systemd/system/nvidia-clock-cap.service`
- `etc/systemd/system/tailscale-autoheal.service`
- `etc/systemd/system/tailscale-autoheal.timer`

## Troubleshooting

- Hypr parse errors: `hyprctl configerrors`
- Reload Hypr config: `hyprctl reload`
- Verify monitor state: `hyprctl monitors all`
- Fastfetch compact profile missing: ensure `config/fastfetch/config-compact.jsonc` is present and linked to `~/.config/fastfetch/config-compact.jsonc`

## Migration Status

This repo has been migrated away from JaKooLit-style layering to a cleaner CachyOS-default baseline. If you rice further, prefer adding changes on top of this baseline instead of reintroducing full upstream replacement trees.
