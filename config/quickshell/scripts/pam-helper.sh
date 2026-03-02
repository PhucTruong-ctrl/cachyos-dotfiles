#!/usr/bin/env bash
# pam-helper.sh — PAM password authentication bridge for Quickshell lock screen.
#
# Usage:
#   echo "$password" | bash pam-helper.sh
#
# Reads password from stdin (one line), validates via libpam using Python ctypes.
# Uses the 'hyprlock' PAM service (same as hyprlock itself).
# Outputs "OK" to stdout on success, "FAIL" on failure.
# Exit code: 0 on success, 1 on failure.
#
# Security:
#   - Password is passed via stdin only (never via argv or env)
#   - No logging of password material
#   - Uses the system PAM stack (pam_faillock honours brute-force protection)

set -euo pipefail

# Delegate to the co-located Python module.
# Python reads the password from its own stdin (piped from our caller).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "${SCRIPT_DIR}/pam_auth.py" "$USER"
