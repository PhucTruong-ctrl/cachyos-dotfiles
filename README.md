# CachyOS Dotfiles

A lean, from-scratch Hyprland setup on **CachyOS** — no pre-built rice frameworks, no JaKooLit, no Ambxst. Every pixel is owned and understood.

The shell UI (bar, launcher, power menu, notifications) is a single custom **Quickshell** codebase written in QML. Everything else follows the **CachyOS default Hyprland baseline** (`cachyos-hyprland-settings`) with targeted personal overrides.

---

## Stack

| Layer | Tool |
|---|---|
| OS | CachyOS (Arch-based, `linux-cachyos` kernel) |
| Window Manager | Hyprland 0.54.x |
| Shell UI | **Quickshell** (custom QML — Bar, Launcher, Power Menu, Notifs) |
| Lock / Idle | Hyprlock + Hypridle |
| Terminal | Ghostty |
| Shell | Zsh + Oh My Zsh + Starship |
| File Manager | Thunar |
| Input Method | Fcitx5 + Bamboo (Vietnamese) |
| Screenshot | Grimblast |
| Theming | Catppuccin Mocha throughout |

> **What was removed:** Waybar, Mako, Wlogout, Wofi, and Swaylock were fully replaced by the Quickshell UI stack. JaKooLit and Ambxst config trees are gone.

---

## Repository Layout

```text
cachyos-dotfiles/
├── config/                         # User-level configs → stowed into ~/.config
│   ├── fastfetch/                  # Fetch profile (config-compact.jsonc)
│   ├── fcitx5/                     # Input method config (Bamboo Vietnamese)
│   ├── ghostty/                    # Terminal emulator settings
│   ├── git/                        # ~/.gitconfig
│   ├── gtk-3.0/ gtk-4.0/          # GTK theme overrides (Catppuccin Mocha)
│   ├── hypr/                       # Hyprland WM config (modular)
│   │   ├── hyprland.conf           # Root config — sources everything below
│   │   ├── hypridle.conf           # Idle → dim → lock → suspend chain
│   │   ├── hyprlock.conf           # Lock screen appearance
│   │   └── config/
│   │       ├── animations.conf
│   │       ├── autostart.conf      # exec-once: quickshell, hypridle, etc.
│   │       ├── colors.conf
│   │       ├── decorations.conf
│   │       ├── defaults.conf       # $terminal, $applauncher, $powermenu vars
│   │       ├── environment.conf
│   │       ├── input.conf
│   │       ├── keybinds.conf
│   │       ├── monitor.conf
│   │       ├── variables.conf
│   │       └── windowrules.conf
│   ├── Kvantum/                    # Qt/KvantumManager theme
│   ├── qt5ct/ qt6ct/               # Qt color palette settings
│   ├── quickshell/                 # Custom shell UI (QML)
│   │   ├── shell.qml               # Entrypoint — loads all components
│   │   └── components/
│   │       ├── Bar.qml             # Top panel (workspaces + clock, per-monitor)
│   │       ├── Launcher.qml        # App launcher (fuzzy, .desktop-driven)
│   │       ├── Notifs.qml          # Notification daemon (replaces mako/dunst)
│   │       └── Power.qml           # Power menu overlay
│   ├── starship.toml               # Shell prompt theme
│   ├── tmux/                       # Tmux settings
│   └── zsh/                        # Zsh config (.zshrc)
├── etc/                            # System-level configs → deployed via sudo cp
│   ├── default/limine              # Bootloader kernel parameters
│   ├── intel-undervolt.conf        # CPU undervolt offsets
│   ├── modprobe.d/                 # Kernel module options
│   ├── sysctl.d/99-performance.conf
│   ├── tlp.conf                    # Power management (TLP)
│   ├── udev/rules.d/               # Udev rules (e.g. VIA keyboard)
│   └── systemd/system/
│       ├── nvidia-clock-cap.service
│       ├── tailscale-autoheal.service
│       └── tailscale-autoheal.timer
├── packages/
│   ├── official.txt                # Pacman packages (single source of truth)
│   └── aur.txt                     # AUR packages (paru)
├── scripts/
│   └── install-packages.sh
└── install.sh                      # Full restore script (idempotent)
```

---

## Quickshell UI

All desktop UI components live in `config/quickshell/`. The entrypoint is:

```bash
quickshell -p ~/.config/quickshell/shell.qml
```

This is launched automatically via `exec-once` in `config/hypr/config/autostart.conf`.

### Components

| File | Purpose |
|---|---|
| `Bar.qml` | Top panel — live workspace pills (Catppuccin Mocha mauve) + clock. One `PanelWindow` per monitor, hotplug-aware via `Variants`. Uses `exclusiveZone: 40` so tiled windows never slide under the bar. |
| `Launcher.qml` | Keyboard-driven app launcher. Reads `.desktop` files, fuzzy search. Toggled via `qs ipc call toggle-launcher toggle`. |
| `Power.qml` | Fullscreen power overlay. Buttons: lock, suspend, logout, reboot, shutdown. Toggled via `qs ipc call toggle-power toggle`. |
| `Cheatsheet.qml` | Fullscreen keybind cheatsheet overlay. Parses Hyprland `bindd` descriptions and toggles via `qs ipc call toggle-cheatsheet toggle`. |
| `Notifs.qml` | Notification daemon — implements `org.freedesktop.Notifications` D-Bus interface. Replaces `mako`/`dunst`. Ephemeral popup cards in the top-right corner. |

> **Design rule:** `shell.qml` is a pure loader — no layout logic lives there. Each component owns its own `IpcHandler` and visibility state.

---

## Keyboard Shortcuts

`$mainMod` is `SUPER` (Windows key).

### Essential

| Shortcut | Action |
|---|---|
| `Mod + Enter` | Open terminal (Ghostty) |
| `Mod + Q` | Close active window |
| `Mod + D` | Open app **Launcher** (Quickshell) |
| `Mod + Backspace` | Open **Power Menu** (Quickshell) |
| `Mod + L` | **Lock** screen (Hyprlock via `loginctl lock-session`) |
| `Mod + E` | Open file manager (Thunar) |
| `Mod + B` | Open browser (Firefox) |
| `Mod + F` | Toggle fullscreen |
| `Mod + V` | Toggle float/tile |

### Workspaces

| Shortcut | Action |
|---|---|
| `Mod + 1–0` | Switch to workspace 1–10 |
| `Mod + Ctrl + 1–0` | Move window to workspace 1–10 (and follow) |
| `Mod + Shift + 1–0` | Move window silently to workspace 1–10 |
| `Mod + ,` / `Mod + .` | Cycle workspaces |
| `Mod + /` | Toggle **Keybind Cheatsheet** (Quickshell) |
| `Mod + Shift + /` | Jump to previous workspace |
| `Mod + -` / `Mod + =` | Move window to / toggle special (scratchpad) workspace |

### Screenshots

| Shortcut | Action |
|---|---|
| `Print` | Screenshot region → clipboard (Grimblast) |
| `Ctrl + Print` | Screenshot active window → clipboard |
| `Alt + Print` | Screenshot active monitor → clipboard |

### Window Management

| Shortcut | Action |
|---|---|
| `Mod + Arrow` | Move focus |
| `Mod + Shift + Arrow` | Move window in direction |
| `Mod + R` | Enter resize submap (then arrows to resize, `Esc` to exit) |
| `Mod + Ctrl + Shift + Arrow` | Quick resize (no submap) |
| `Mod + K` | Toggle window group |
| `Mod + Tab` | Cycle within window group |
| `Mod + Y` | Pin window to all workspaces |

---

## Idle / Lock Chain

Managed by `hypridle` (config: `config/hypr/hypridle.conf`):

| Timeout | Action |
|---|---|
| 2.5 min | Dim screen to 20% (`brightnessctl`) |
| 5 min | Lock screen (`loginctl lock-session` → `hyprlock`) |
| 15 min | Suspend (`systemctl suspend`) |

Before sleep, the session is locked so you wake to a locked screen. After wake, DPMS is re-enabled automatically.

---

## Deploy (Install / Restore)

```bash
git clone git@github.com:PhucTruong-ctrl/cachyos-dotfiles.git ~/cachyos-dotfiles
cd ~/cachyos-dotfiles

# Preview all changes without applying
bash install.sh --dry-run

# Apply everything
bash install.sh
```

`install.sh` runs sequentially and blocks until complete:

1. Installs packages from `packages/official.txt` and `packages/aur.txt`
2. Copies `etc/` files to `/etc/` with `sudo cp`
3. Installs and enables systemd services
4. Installs Oh My Zsh (skipped if already present)
5. Stows `config/` into `~/.config` with `stow --restow`
6. Creates direct symlinks: `~/.zshrc`, `~/.gitconfig`
7. Sets Zsh as default shell
8. Adds user to `plugdev`, `input`, `docker` groups
9. Applies `sysctl` settings and regenerates boot entries
10. Refreshes font cache

### Stow Model

```bash
# Symlink model: every item under config/ becomes ~/.config/<item>
stow --target="$HOME/.config" --restow config

# Verify key links
for item in hypr quickshell ghostty; do
  ls -ld "$HOME/.config/$item"
done
```

---

## Package Manifests

| File | Manager | Usage |
|---|---|---|
| `packages/official.txt` | `pacman` | One package per line, alphabetical |
| `packages/aur.txt` | `paru` | One package per line |

To install packages only:

```bash
bash scripts/install-packages.sh
```

When adding a new tool, append its package name to the appropriate file. Do not add duplicates. Do not add pip/npm/cargo packages here — only Pacman/AUR.

---

## System Tuning (`etc/`)

These files require root to deploy and are managed by `install.sh`:

| File | Purpose |
|---|---|
| `etc/intel-undervolt.conf` | CPU core/cache/uncore voltage offsets |
| `etc/tlp.conf` | TLP power management (battery charge thresholds, USB autosuspend) |
| `etc/sysctl.d/99-performance.conf` | Kernel tunables (`vm.swappiness`, `nmi_watchdog`, etc.) |
| `etc/default/limine` | Bootloader kernel parameters (`intel_pstate=passive`, etc.) |
| `etc/systemd/system/nvidia-clock-cap.service` | NVIDIA GPU clock cap on boot |
| `etc/systemd/system/tailscale-autoheal.{service,timer}` | Auto-reconnect Tailscale on network changes |
| `etc/udev/rules.d/99-via-keyboard.rules` | VIA keyboard firmware flashing permissions |
| `etc/modprobe.d/` | Kernel module options |

---

## Hyprland Notes

### Configuration is modular

`config/hypr/hyprland.conf` only sources sub-files — do not put rules directly in it.

Put changes in the relevant sub-file under `config/hypr/config/`:

| Sub-file | What goes here |
|---|---|
| `keybinds.conf` | All `bind` / `bindd` / `bindel` / `bindm` lines |
| `autostart.conf` | `exec-once` lines |
| `windowrules.conf` | Per-app window rules |
| `monitor.conf` | Monitor layout and scaling |
| `defaults.conf` | App variable definitions (`$terminal`, `$applauncher`, etc.) |
| `animations.conf`, `decorations.conf` | Visual tuning |
| `input.conf` | Keyboard/mouse/touchpad settings |
| `environment.conf` | `env =` exports for the session |

### Syntax rules (0.53+)

Do **not** use `windowrulev2` — it is deprecated. Use the new unified syntax:

```ini
# Bad (deprecated)
windowrulev2 = float, class:^(pavucontrol)$

# Good (0.53+)
windowrule = match:class pavucontrol, float on
```

### Verification

```bash
# Check for parse errors (must return no output)
hyprctl configerrors

# Reload without restarting
hyprctl reload

# Inspect monitor state
hyprctl monitors all

# Check window class/title for rule targeting
hyprctl clients | grep -E 'class|title'
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Bar not visible | Check `quickshell` is running: `pgrep -x quickshell`. Reload: `pkill quickshell && quickshell -p ~/.config/quickshell/shell.qml &` |
| Launcher / Power menu doesn't open | Confirm IPC: `qs ipc call toggle-launcher toggle`, `qs ipc call toggle-cheatsheet toggle` |
| Notifications not appearing | Quickshell's `Notifs.qml` registers on D-Bus. Check: `busctl --user list \| grep freedesktop.Notifications` |
| Hyprland config errors | `hyprctl configerrors` |
| Stow conflicts | Remove conflicting dir: `rm -rf ~/.config/<dir>` then re-run stow |
| Fastfetch missing profile | Verify `~/.config/fastfetch/config-compact.jsonc` is a symlink |
| Screen not locking on suspend | Ensure `hypridle` is running: `pgrep -x hypridle` |

---

## Post-Install Checklist

```
[ ] Reboot to apply boot kernel parameters
[ ] gh auth login           — GitHub CLI authentication
[ ] tailscale up            — connect to Tailscale
[ ] fcitx5 -r -d            — reload input method
[ ] sudo intel-undervolt read  — verify undervolt applied
[ ] spicetify backup apply  — activate Spicetify (after Spotify first launch)
[ ] betterdiscordctl install   — inject BetterDiscord
```
