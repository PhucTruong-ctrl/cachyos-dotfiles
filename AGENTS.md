# Agent Rules (AGENTS.md)

This file contains rules and guidelines for AI coding agents operating in the `cachyos-dotfiles` repository.

## 1. Project Overview & Architecture
This repository tracks system configurations, user dotfiles, and provisioning scripts for a **CachyOS (Arch-based)** environment running **Hyprland**. 
The repository moved away from heavy third-party dotfiles (like JaKooLit) and now prefers building on top of the **CachyOS defaults baseline**.

### Key Architectural Decisions
- **Dotfile Deployment**: Uses GNU `stow` to symlink configurations from `config/*` into `~/.config/`.
- **System Configs (Static)**: `/etc/` files (like `sysctl`, `tlp`, `udev`, `systemd` services) are deployed via standard `cp` running as root/sudo through the installer script.
- **Hyprland Modularity**: The `config/hypr/hyprland.conf` file is modularized. Modifications should go into the relevant `config/hypr/config/*.conf` file (e.g., `keybinds.conf`, `monitor.conf`, `windowrules.conf`).
- **Compositor Standard**: Hyprland version 0.53.3+ syntax rules MUST be used (e.g., `windowrule = match:class name, float on` instead of `windowrulev2`).
- **Package Management**: Explicitly declared in `packages/official.txt` and `packages/aur.txt`. The script `scripts/install-packages.sh` reads these directly.

## 2. Terminal & Tool Standards
- **Wait for Completion**: Never leave the `install.sh` running in the background. Scripts should run sequentially and block until completion.
- **Root Elevation**: Sudo requires a password in this environment. Avoid using `sudo` inside automated scripts unless absolutely necessary or if you can authenticate securely.
- **Bash over Zsh**: Provisioning scripts (`install.sh`, `scripts/*.sh`) are written in Bash for portability, even though the user's interactive shell is Zsh.
- **No Symlink Mess**: Always verify existing directories/files before running `stow`. Remove existing target directories if they conflict with `stow --adopt` or `stow --target="$HOME/.config" config`.

## 3. Build, Lint & Test Commands
There is no automated CI/CD or compilation step in this repository, as it is a collections of scripts and configuration files. Verification is done entirely at runtime.

### Runtime Verification Commands
- **Hyprland Parsing**: `hyprctl configerrors` (MUST return no output to be considered valid)
- **Waybar Validation**: Run `waybar -c ~/.config/waybar/config -s ~/.config/waybar/style.css -l info` to test bar parsing
- **Fastfetch**: `fastfetch --config ~/.config/fastfetch/config-compact.jsonc`
- **Shell Scripts**: Ensure all `.sh` scripts pass ShellCheck: `shellcheck scripts/*.sh install.sh`

## 4. Code Style & Modification Guidelines

### Shell Scripts (`install.sh`, `scripts/*.sh`)
- Use Bash `set -e` (and optionally `set -u` and `set -o pipefail`) in all executable scripts.
- Prioritize idempotency. A script should be safe to run multiple times (e.g., use `mkdir -p`, check if packages are installed before `yay -S`).
- Use informative logging prefixes (e.g., `[INFO]`, `[WARN]`, `[ERROR]`) for standard output.
- Variable naming: `UPPER_CASE` for global constants, `lowercase` for local variables inside functions.

### Hyprland Configuration (`config/hypr/**/*.conf`)
- Keep comments cleanly formatted above the rule they describe.
- Do NOT use `windowrulev2`. It is deprecated. Use the `windowrule = match:type value, action` syntax for 0.53+.
  - Bad: `windowrulev2 = float, class:^(pavucontrol)$`
  - Good: `windowrule = match:class pavucontrol, float on`
- Do NOT hardcode file paths that assume the repository location. Use relative paths for `source` directives mapped from `~/.config/hypr/`.
  - Example: `source = ~/.config/hypr/config/keybinds.conf`

### Systemd/Sysctl/TLP (System configs in `etc/`)
- Do not track sensitive credentials or machine-unique hardware IDs (like exact MAC addresses or Wi-Fi passwords) in the `/etc/` structure.
- When modifying power/thermal states (e.g., `intel-undervolt.conf` or `nvidia-clock-cap`), ensure there is a clear comment explaining *why* the override exists.

### Modifying Package Manifests
- `packages/official.txt` and `packages/aur.txt` must NOT contain duplicates.
- Ensure package names match exact Arch/AUR repositories. Do not add pip/npm packages here.
- Maintain a clean list without trailing whitespace. If removing a configuration (like JaKooLit), proactively prune the visual dependencies from these lists.

## 5. Agent Workflow Rules
1. **Analyze First**: Run `hyprctl version`, `git status`, or read `README.md` to understand context before touching configs.
2. **Atomic Changes**: If replacing a GUI component (e.g. changing launcher from `wofi` to `rofi`), you must update keybinds, package lists, AND the relevant `config/` directory simultaneously.
3. **Recovery Plan**: If modifying Hyprland `keybinds.conf` or `monitor.conf`, ensure a fallback exists so the user does not get locked out of a usable display.
4. **Commit Hygiene**: Ensure dotfiles modifications are appropriately staged without pulling in garbage files (like `.swp`, `.bak`, or `.hive` directories which should be explicitly generated or `.gitignore`'d).