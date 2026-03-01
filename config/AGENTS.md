# config/ — Agent Instructions

This directory is the **single source of truth for all user-level dotfiles**. Everything here is deployed to `~/.config/` via **GNU Stow** and must remain stow-compatible.

---

## How Deployment Works

```bash
stow --target="$HOME/.config" --restow config
```

Each top-level subdirectory under `config/` (e.g. `config/hypr/`) becomes a symlink at `~/.config/hypr/`. Individual files are **not** copied — they are **symlinked**. This means:

- Editing a file here is immediately live in the running session.
- Never create files directly under `~/.config/` when they belong in this repo — put them here and re-stow.
- Before running stow, verify no real directories exist at the target path. A pre-existing `~/.config/hypr/` that is not a symlink will cause a conflict. Remove it first: `rm -rf ~/.config/<dir>`.

Two extra symlinks are created outside `~/.config/` by `install.sh`:

| Repo path | Symlink target |
|---|---|
| `config/zsh/.zshrc` | `~/.zshrc` |
| `config/git/config` | `~/.gitconfig` |

---

## Directory Map

| Path | Purpose |
|---|---|
| `fastfetch/` | Fastfetch fetch profiles. The compact profile is at `fastfetch/config-compact.jsonc`. |
| `fcitx5/` | Fcitx5 input method configuration. Controls Bamboo Vietnamese input and keyboard switching. Do not regenerate from `fcitx5-configtool` and commit raw binary blobs — keep it as human-readable config. |
| `ghostty/` | Ghostty terminal emulator settings (font, theme, opacity, keybinds). |
| `git/` | Git client config (`config` file maps to `~/.gitconfig`). Contains identity, default branch, pager, and credential settings. |
| `gtk-3.0/` `gtk-4.0/` | GTK theme overrides. Currently targets Catppuccin Mocha. Edit `settings.ini` and `gtk.css`. |
| `hypr/` | **Hyprland WM config** — see dedicated section below. |
| `Kvantum/` | KvantumManager Qt theme. Contains the active theme directory and `kvantum.kvconfig`. |
| `qt5ct/` `qt6ct/` | Qt5/Qt6 color palette and font settings. Ensures Qt apps respect the Catppuccin Mocha palette without KDE Plasma. |
| `quickshell/` | **Custom shell UI** — see dedicated section below. |
| `starship.toml` | Starship prompt configuration. Note: this is a bare file, not a subdirectory. Stow places it at `~/.config/starship.toml`. |
| `tmux/` | Tmux terminal multiplexer config. |
| `zsh/` | Zsh config. `zsh/.zshrc` is symlinked to `~/.zshrc` directly. |

---

## Hyprland Config (`config/hypr/`)

### Structure

```
hypr/
├── hyprland.conf        ← Root file. Sources everything else. Do NOT put rules here.
├── hypridle.conf        ← Idle management (dim → lock → suspend chain)
├── hyprlock.conf        ← Lock screen appearance
└── config/
    ├── animations.conf
    ├── autostart.conf   ← exec-once entries (quickshell, hypridle, etc.)
    ├── colors.conf
    ├── decorations.conf
    ├── defaults.conf    ← App variable definitions ($terminal, $applauncher, etc.)
    ├── environment.conf ← env = exports
    ├── input.conf       ← Keyboard/mouse/touchpad settings
    ├── keybinds.conf    ← All bind / bindd / bindel / bindm lines
    ├── monitor.conf     ← Monitor layout and scaling
    ├── variables.conf   ← General Hyprland settings (gaps, borders, etc.)
    └── windowrules.conf ← Per-app window rules
```

### Rules for Agents

1. **Do not modify `hyprland.conf` directly.** It is a pure source-file loader. Put changes in the appropriate sub-file.

2. **Syntax version: Hyprland 0.53+.** Use the unified `windowrule` syntax, never `windowrulev2`:
   ```ini
   # WRONG — deprecated
   windowrulev2 = float, class:^(pavucontrol)$

   # CORRECT — 0.53+
   windowrule = match:class pavucontrol, float on
   ```

3. **Quickshell IPC commands** are defined in `defaults.conf`:
   ```ini
   $applauncher = qs ipc call toggle-launcher toggle
   $powermenu   = qs ipc call toggle-power toggle
   ```
   If you rename an IPC handler in `quickshell/`, update the matching variable here.

4. **Verify after every change:**
   ```bash
   hyprctl configerrors   # must return no output
   hyprctl reload
   ```

5. **Keybind changes** in `keybinds.conf` must have a corresponding recovery path — never remove `Mod+Enter` (terminal) or `Mod+Q` (close) without adding an equivalent.

6. **Monitor config** in `monitor.conf` uses the format:
   ```ini
   monitor = eDP-1, 1920x1080@60, 0x0, 1.5
   ```
   Do not hardcode monitor names from other machines. Use `monitor = ,preferred,auto,1` as a safe fallback.

---

## Quickshell Config (`config/quickshell/`)

### What This Is

A fully custom, monolithic shell UI written in QML using the [Quickshell](https://quickshell.outfoxxed.me/) compositor shell framework. It **replaces** Waybar, Mako, Wlogout, and Wofi entirely.

Launched at login by:
```bash
exec-once = quickshell -p ~/.config/quickshell/shell.qml
```

### Structure

```
quickshell/
├── shell.qml            ← Entrypoint: ShellRoot that loads all components
└── components/
    ├── Bar.qml          ← Top panel (workspaces + clock, one PanelWindow/monitor)
    ├── Launcher.qml     ← App launcher overlay
    ├── Notifs.qml       ← Notification daemon (org.freedesktop.Notifications)
    └── Power.qml        ← Power menu overlay
```

### Design Invariants — Do Not Break These

1. **`shell.qml` is a pure loader.** It instantiates components and nothing else. No layout, no UI logic. Keep it that way.

2. **Each component owns its own visibility.** Overlays (`Launcher`, `Power`) use an internal `IpcHandler` to toggle themselves. Do not control overlay visibility from `shell.qml`.

3. **`Bar.qml` must use `exclusiveZone: 40`** (not `exclusionMode`) to reserve space on the compositor. This prevents tiled windows from sliding under the bar. Do not change this to `exclusionMode: ExclusionMode.Normal` — it races on startup.

4. **IPC toggle names must match `defaults.conf`:**
   - Launcher IPC name: `toggle-launcher`
   - Power menu IPC name: `toggle-power`
   If you rename an `IpcHandler` inside a component, update `config/hypr/config/defaults.conf` simultaneously.

5. **Theme is Catppuccin Mocha.** Use these palette values consistently:
   | Name | Hex |
   |---|---|
   | Base (background) | `#1e1e2e` |
   | Surface0 | `#313244` |
   | Text | `#cdd6f4` |
   | Mauve (accent) | `#cba6f7` |
   | Red (urgent) | `#f38ba8` |

6. **`watchFiles: true` is set in `shell.qml`.** Quickshell will hot-reload when any `.qml` source is saved. Use this for rapid iteration; you do not need to restart Quickshell to see changes during development.

### Adding a New Component

1. Create `components/NewComponent.qml`
2. Import and instantiate it in `shell.qml`: `NewComponent {}`
3. If it's a togglable overlay, add an `IpcHandler` inside it with a unique name
4. If it needs a keybind, add `$newcomponent = qs ipc call <name> toggle` to `defaults.conf` and wire a `bindd` in `keybinds.conf`

### Verification

```bash
# Check IPC is working
qs ipc call toggle-launcher toggle
qs ipc call toggle-power toggle

# Restart Quickshell cleanly
pkill quickshell && quickshell -p ~/.config/quickshell/shell.qml &
```

---

## General Agent Rules for `config/`

- **Always re-stow after structural changes** (adding/removing files or directories):
  ```bash
  stow --target="$HOME/.config" --restow config
  ```
- **Do not commit binary blobs** generated by GUI tools (`.fcitx5/`, KDE wallet files, etc.).
- **Theming is Catppuccin Mocha** across the board. When editing any visual config, consult the palette above and stay consistent.
- **Atomic changes:** If a UI component changes names (e.g. a new launcher replaces the old one), update keybinds, package lists, `defaults.conf`, and the `quickshell/` directory simultaneously — never leave them in a mismatched state.
