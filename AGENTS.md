# Agent Rules (AGENTS.md) — Hive Dedicated Mode

## Core Execution Logic
- **Architect/Planner**: NEVER executes or modifies code. Writes `plan.md`.
- **Swarm/Orchestrator**: NEVER writes code. Manages tasks and merges.
- **Foragers**: Execute work in isolated Git worktrees. Only commit, never merge.

## Strict Operational Bounds & Landmines
- **Hyprland Rules**: `windowrulev2` is STRICTLY BANNED. You MUST use `windowrule = match:class name, float on`.
- **Monolithic UI**: We use **Quickshell** exclusively. Do NOT use Waybar, Mako, Wofi, or Wlogout.
- **Config Deployment**: Use GNU `stow` (e.g., `stow config`). DO NOT copy to `~/.config/`.
- **System Configs**: `/etc/` files must be deployed via `sudo cp` in `install.sh`.
- **Theming**: **Catppuccin Mocha** is the global palette. 
- **Persist Knowledge**: Always write project-specific knowledge to `.hive/contexts/` via `hive_context_write`. Memory is ephemeral.

## Verification Commands (Must Run)
- **Hyprland**: `hyprctl configerrors`
- **Quickshell**: `qs ipc call toggle-launcher toggle`
- **Fastfetch**: `fastfetch --config ~/.config/fastfetch/config-compact.jsonc`
- **Scripts**: `shellcheck scripts/*.sh install.sh`
