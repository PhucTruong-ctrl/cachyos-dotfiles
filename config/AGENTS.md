# config/ — Hive Artifact Rules

- Changes must remain GNU Stow compatible (`stow --restow config`).
- **Hyprland**: Never edit `hyprland.conf` directly (it is a loader). Edit modular files in `config/hypr/config/*.conf`.
- **Quickshell**: Maintain `exclusiveZone: 40` for the Bar.
- **Atomic UI Changes**: If replacing a component, you MUST update package manifests, update keybinds/defaults, prune the old config, and add the new config.
