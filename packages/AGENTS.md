# packages/ — Agent Instructions

This directory is the **single source of truth for all software dependencies** on this system. The two manifests here drive `scripts/install-packages.sh`, which is called by `install.sh` during a full restore.

---

## Files

| File | Package manager | Purpose |
|---|---|---|
| `official.txt` | `pacman` | Arch Linux official repositories (core, extra, community, CachyOS) |
| `aur.txt` | `paru` | AUR (Arch User Repository) packages |

---

## Format Rules — Must Follow Exactly

1. **One package per line.** No inline comments. No blank lines. No trailing whitespace.
2. **Alphabetical order.** Sorted case-insensitively. This makes diffs readable and prevents re-adding packages that are already present.
3. **No duplicates.** Before adding a package, search the file first:
   ```bash
   grep -i 'package-name' packages/official.txt packages/aur.txt
   ```
4. **Exact package names only.** Use the exact name as it appears in `pacman -Si <name>` or `paru -Si <name>`. Do not add version pins, pip packages, npm packages, cargo crates, or Flatpaks here — only Pacman/AUR.
5. **Pacman vs AUR:** If a package exists in both the official repos and AUR, prefer official (`official.txt`). Use AUR only for packages unavailable in official repos.

---

## When to Update These Files

**Always update manifests when:**
- A new tool is introduced to the setup (add it).
- A tool is removed or replaced (remove it and any visual dependencies that only existed for that tool).
- A package is renamed upstream (update the name).

**The rule:** If a program is used by any config file in this repo or is required by `install.sh`, its package must be listed here. If a package is listed here but no config uses it, it should be removed (YAGNI).

---

## How to Add a Package

```bash
# 1. Confirm the package name
pacman -Si package-name       # official
paru -Si package-name         # AUR

# 2. Add to the correct file, maintaining alphabetical order
# Edit packages/official.txt or packages/aur.txt

# 3. Verify no duplicates
sort -u packages/official.txt | diff - packages/official.txt
sort -u packages/aur.txt | diff - packages/aur.txt

# 4. Install immediately (optional, if testing on live system)
bash scripts/install-packages.sh
```

---

## How to Remove a Package

1. Remove the line from the manifest.
2. Check if any config file in `config/` or `etc/` references the tool. If yes, update or remove those configs atomically in the same commit.
3. If the package was a visual dependency (e.g. a notification daemon, launcher, or bar that was replaced), remove its config directory from `config/` too.

> **Example:** When Waybar was replaced by Quickshell, `waybar` was removed from `official.txt` and `config/waybar/` was pruned. `mako`, `wlogout`, and `wofi` were removed at the same time. This is the expected pattern.

---

## Current Dependency Context

Key packages and why they are present:

| Package | Why it's here |
|---|---|
| `quickshell` | Custom shell UI (bar, launcher, power menu, notifications) — replaces Waybar/Mako/Wofi/Wlogout |
| `hypridle` | Idle management daemon (dim → lock → suspend chain) |
| `hyprlock` | Lock screen (triggered by `loginctl lock-session`) |
| `hyprpolkitagent` | Polkit authentication agent for Hyprland (replaces `polkit-kde-agent`) |
| `ghostty` | Primary terminal emulator |
| `grimblast` | Screenshot tool (`Print` keybinds) |
| `stow` | GNU Stow — required by `install.sh` to symlink `config/` |
| `fcitx5` `fcitx5-bamboo` `fcitx5-gtk` `fcitx5-qt` | Vietnamese input method stack |
| `intel-undervolt` | CPU voltage control (paired with `etc/intel-undervolt.conf`) |
| `tlp` `tlp-rdw` | Power management (paired with `etc/tlp.conf`) |
| `thermald` | Intel thermal management daemon |
| `tailscale` | VPN (paired with `etc/systemd/system/tailscale-autoheal.*`) |
| `nvidia-580xx-dkms` `nvidia-580xx-utils` etc. | NVIDIA dkms driver stack for this machine's GPU |
| `swaybg` | Wallpaper setter (used in `autostart.conf`) |
| `wob` | On-screen volume/brightness bar (used in `keybinds.conf` volume logic) |
| `brightnessctl` | Screen brightness control (used in `keybinds.conf` and `hypridle.conf`) |
| `playerctl` | Media playback control (used in `keybinds.conf`) |
| `cliphist` | Clipboard history manager |
| `nwg-displays` | GUI for configuring monitor layout |
| `starship` | Shell prompt (Zsh integration) |

---

## What Does NOT Belong Here

- **pip packages** (`python-*` in official is fine, but not packages installed via `pip install`)
- **npm/cargo/go** global installs
- **Flatpaks** (managed separately via `flatpak install`)
- **AppImages** (managed separately)
- **Fonts** that are bundled inside another config (don't add a font package unless it's actually used in a config)

---

## Validation Snippet

Run this before committing changes to catch common issues:

```bash
# Check for duplicates within each file
echo "=== Duplicates in official.txt ===" && sort official.txt | uniq -d
echo "=== Duplicates in aur.txt ===" && sort aur.txt | uniq -d

# Check both files are sorted
echo "=== Sort check official.txt ===" && sort -c official.txt && echo "OK"
echo "=== Sort check aur.txt ===" && sort -c aur.txt && echo "OK"

# Check for packages that exist in both files (should be moved to official.txt)
comm -12 <(sort official.txt) <(sort aur.txt)
```
