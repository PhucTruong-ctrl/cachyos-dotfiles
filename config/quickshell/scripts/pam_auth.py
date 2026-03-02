#!/usr/bin/env python3
"""
pam_auth.py — libpam authentication helper for the Quickshell lock screen.

Called by pam-helper.sh.  Reads the password from stdin (one line), then
authenticates via libpam using the 'hyprlock' PAM service.

Outputs:
  OK   (exit 0) — PAM accepted the password
  FAIL (exit 1) — PAM rejected the password or an error occurred

Security:
  - Password read from stdin only; never passed via argv or environment.
  - No logging of password material.
  - Uses the system PAM stack (pam_faillock honours brute-force protection).
"""

import ctypes
import ctypes.util
import os
import sys

# ---------------------------------------------------------------------------
# libpam setup
# ---------------------------------------------------------------------------

lib_path = ctypes.util.find_library("pam")
if not lib_path:
    sys.stdout.write("FAIL\n")
    sys.exit(1)

libpam = ctypes.cdll.LoadLibrary(lib_path)

# Use libc for malloc/strdup so PAM can free() the response strings correctly.
libc = ctypes.CDLL("libc.so.6")
libc.malloc.restype = ctypes.c_void_p
libc.malloc.argtypes = [ctypes.c_size_t]
libc.strdup.restype = ctypes.c_void_p
libc.strdup.argtypes = [ctypes.c_char_p]
libc.memset.restype = ctypes.c_void_p
libc.memset.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_size_t]

# ---------------------------------------------------------------------------
# PAM structures
# ---------------------------------------------------------------------------

PAM_SUCCESS = 0
PAM_PROMPT_ECHO_OFF = 1  # password prompt (no echo)
PAM_PROMPT_ECHO_ON = 2  # username prompt (with echo) — rare in hyprlock stack


class PamMessage(ctypes.Structure):
    _fields_ = [("msg_style", ctypes.c_int), ("msg", ctypes.c_char_p)]


class PamResponse(ctypes.Structure):
    _fields_ = [("resp", ctypes.c_char_p), ("resp_retcode", ctypes.c_int)]


CONV_FUNC = ctypes.CFUNCTYPE(
    ctypes.c_int,
    ctypes.c_int,
    ctypes.POINTER(ctypes.POINTER(PamMessage)),
    ctypes.POINTER(ctypes.POINTER(PamResponse)),
    ctypes.c_void_p,
)


class PamConv(ctypes.Structure):
    _fields_ = [("conv", CONV_FUNC), ("appdata_ptr", ctypes.c_void_p)]


# ---------------------------------------------------------------------------
# Read credentials
# ---------------------------------------------------------------------------

# Password comes from stdin (piped by pam-helper.sh)
password = sys.stdin.readline().rstrip("\n")
username = os.environ.get("USER", "") or os.getlogin()


# ---------------------------------------------------------------------------
# PAM conversation callback
# ---------------------------------------------------------------------------


def pam_conv_func(num_msg, msg, resp, appdata_ptr):
    """Supply the password for each PAM prompt that requires a response."""
    resp_size = ctypes.sizeof(PamResponse) * num_msg
    resp_mem = libc.malloc(resp_size)
    if not resp_mem:
        return 1  # PAM_BUF_ERR

    libc.memset(resp_mem, 0, resp_size)
    resp_array = (PamResponse * num_msg).from_address(resp_mem)

    for i in range(num_msg):
        m = msg[i].contents
        # Respond to password (and echo-on) prompts with the supplied password.
        # PAM_ERROR_MSG (3) and PAM_TEXT_INFO (4) get a null resp — safe to ignore.
        if m.msg_style in (PAM_PROMPT_ECHO_OFF, PAM_PROMPT_ECHO_ON):
            # strdup allocates a copy that PAM will free() after use.
            pwd_ptr = libc.strdup(password.encode("utf-8"))
            resp_array[i].resp = ctypes.cast(pwd_ptr, ctypes.c_char_p)
            resp_array[i].resp_retcode = 0

    resp[0] = ctypes.cast(resp_mem, ctypes.POINTER(PamResponse))
    return 0  # PAM_SUCCESS


conv_func = CONV_FUNC(pam_conv_func)
conv = PamConv(conv_func, None)

# ---------------------------------------------------------------------------
# Authenticate
# ---------------------------------------------------------------------------

pamh = ctypes.c_void_p()
ret = libpam.pam_start(
    b"hyprlock",
    username.encode("utf-8"),
    ctypes.byref(conv),
    ctypes.byref(pamh),
)
if ret != PAM_SUCCESS:
    sys.stdout.write("FAIL\n")
    sys.exit(1)

ret = libpam.pam_authenticate(pamh, 0)
libpam.pam_end(pamh, ret)

if ret == PAM_SUCCESS:
    sys.stdout.write("OK\n")
    sys.exit(0)
else:
    sys.stdout.write("FAIL\n")
    sys.exit(1)
