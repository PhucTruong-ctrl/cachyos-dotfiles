# etc/ — System-Level Propolis

- **Deployment**: Must deploy via `sudo cp`.
- **No Secrets**: Never commit or store secrets (Wi-Fi passwords, UUIDs, MAC addresses) here.
- **Comments Required**: Every tunable in `sysctl.d/` or `intel-undervolt.conf` must have a comment explaining WHY it exists.
- **Verification**: Run `systemd-analyze verify` for units or `intel-undervolt read` for voltage checks.
