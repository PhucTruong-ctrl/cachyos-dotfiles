# etc/ — Agent Instructions

This directory mirrors the **`/etc/` filesystem** for system-level configuration files that require root privileges to apply. Every file here is deployed by `install.sh` using `sudo cp`.

---

## How Deployment Works

There is **no symlink model** for `etc/`. Files are copied verbatim to their target paths. This means:

- Changes here **do not take effect automatically** — you must re-run the relevant `sudo cp` command or run `install.sh`.
- After editing a file, copy it manually to test:
  ```bash
  sudo cp etc/tlp.conf /etc/tlp.conf
  sudo systemctl restart tlp
  ```
- The full restore path is:
  ```bash
  bash install.sh
  # or just the system configs section:
  sudo cp etc/intel-undervolt.conf /etc/intel-undervolt.conf
  sudo cp etc/tlp.conf /etc/tlp.conf
  sudo cp etc/sysctl.d/99-performance.conf /etc/sysctl.d/99-performance.conf
  sudo cp etc/udev/rules.d/99-via-keyboard.rules /etc/udev/rules.d/99-via-keyboard.rules
  sudo cp etc/default/limine /etc/default/limine
  sudo cp etc/systemd/system/tailscale-autoheal.service /etc/systemd/system/
  sudo cp etc/systemd/system/tailscale-autoheal.timer /etc/systemd/system/
  sudo cp etc/systemd/system/nvidia-clock-cap.service /etc/systemd/system/
  sudo systemctl daemon-reload
  ```

---

## File Map

```
etc/
├── default/
│   └── limine               # Bootloader kernel command-line parameters
├── intel-undervolt.conf     # CPU voltage offsets (core, cache, uncore, iGPU)
├── modprobe.d/              # Kernel module options (e.g. NVIDIA, i915 overrides)
├── sysctl.d/
│   └── 99-performance.conf  # Kernel runtime tunables
├── systemd/
│   └── system/
│       ├── nvidia-clock-cap.service   # Caps NVIDIA GPU clock on boot
│       ├── tailscale-autoheal.service # Reconnects Tailscale on network changes
│       └── tailscale-autoheal.timer   # Timer unit for tailscale-autoheal
├── tlp.conf                 # TLP power management daemon config
└── udev/
    └── rules.d/
        └── 99-via-keyboard.rules  # Grants firmware-flash access to VIA keyboards
```

---

## File-by-File Notes

### `etc/intel-undervolt.conf`

Controls CPU voltage offsets via the `intel-undervolt` tool. Applied on boot by the `intel-undervolt` systemd service.

**Rules:**
- Always include a comment explaining WHY a specific offset is set (thermal headroom, stability, etc.).
- Do not set offsets more aggressive than what has been validated as stable. If unsure, use `-0 mV` (no change) as a safe default.
- After editing, verify with:
  ```bash
  sudo intel-undervolt read
  sudo intel-undervolt apply
  ```
- Values are machine-specific (CPU silicon lottery). Do not assume the same offsets work on a different machine.

### `etc/tlp.conf`

TLP power management — battery charge thresholds, USB autosuspend, CPU governor policy, PCIe ASPM.

**Rules:**
- Do not remove documented section headers — TLP's config is dense and section headers are the primary navigation aid.
- Battery thresholds (`START_CHARGE_THRESH_BAT0`, `STOP_CHARGE_THRESH_BAT0`) are tuned for battery longevity. Do not raise `STOP` above 80 without a deliberate reason.
- After editing: `sudo systemctl restart tlp && sudo tlp-stat -s`

### `etc/sysctl.d/99-performance.conf`

Kernel tunables applied at boot and via `sudo sysctl --system`.

**Rules:**
- Every non-obvious tunable must have a comment explaining its purpose and the tradeoff.
- Apply changes without rebooting: `sudo sysctl --system`
- Do not include settings that break containers or Docker networking (e.g. be cautious with `net.ipv4.ip_forward`).

### `etc/default/limine`

Bootloader kernel command-line parameters. Parsed by `limine-mkinitcpio-hook` to regenerate boot entries.

**Rules:**
- After editing, regenerate: `sudo limine-mkinitcpio`
- Dangerous parameters (`ro`/`rw`, IOMMU settings, `quiet`/`splash`) must be tested with a fallback boot entry.
- Do not add parameters you cannot explain. Each param should have an inline comment.

### `etc/systemd/system/`

Custom systemd unit files. Deployed by `install.sh` and enabled/started there too.

**Rules:**
- After copying a changed unit: `sudo systemctl daemon-reload`
- Verify unit syntax before deploying: `systemd-analyze verify /etc/systemd/system/<unit>.service`
- All units must have `[Unit]` `Description=` set to a clear human-readable string.
- Do not track sensitive environment variables (secrets, API keys) in unit files here.

**`nvidia-clock-cap.service`** — Runs at startup to cap the NVIDIA GPU max clock. Prevents thermal throttling under sustained load. The cap value and the reason for it must be in a comment.

**`tailscale-autoheal.{service,timer}`** — A timer-triggered service that detects a broken Tailscale connection (e.g. after network switch) and re-runs `tailscale up` to reconnect automatically.

### `etc/udev/rules.d/99-via-keyboard.rules`

Grants the `plugdev` group access to USB HID devices matching the VIA keyboard vendor/product IDs, enabling firmware flashing without root.

**Rules:**
- Do not add broad `SUBSYSTEM=="usb"` rules without vendor/product ID filters — that is a security risk.
- If adding rules for a new device, use `udevadm info` to identify exact attributes.
- After deploying: `sudo udevadm control --reload-rules && sudo udevadm trigger`

### `etc/modprobe.d/`

Kernel module options (e.g. `options nvidia NVreg_PreserveVideoMemoryAllocations=1` for suspend/resume, blacklisting conflicting modules).

**Rules:**
- Changes require a reboot or `sudo modprobe -r <module> && sudo modprobe <module>` (only safe if the module is not in use).
- Each options file should be named after the module it configures (e.g. `nvidia.conf`, `i915.conf`).

---

## Security Rules for All Files in `etc/`

1. **No secrets.** Do not commit Wi-Fi passwords, VPN pre-shared keys, API tokens, machine-specific UUIDs, or MAC addresses.
2. **No world-writable permissions.** All files here should be owned `root:root` with mode `644` or stricter when deployed.
3. **Machine-specific values** (exact undervolt offsets, GPU IDs, USB VID/PID) are acceptable and expected — just document them clearly.

---

## Testing System Config Changes

Because these files require root and affect running services, there is no automated test suite. Use this manual checklist:

```bash
# 1. Validate the file content before deploying
systemd-analyze verify etc/systemd/system/<unit>.service  # for units
sysctl --system --dry-run                                  # where supported

# 2. Deploy and check the service
sudo cp etc/<file> /etc/<file>
sudo systemctl daemon-reload
sudo systemctl restart <service>
sudo systemctl status <service>

# 3. Check for errors in the journal
journalctl -xe -u <service> --no-pager | tail -40
```
