"""macOS TCC permission checks for Screen Recording and Accessibility."""

from __future__ import annotations

import ctypes
import sys

_APPLICATION_SERVICES_PATH = (
    "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
)


def _check_screen_recording(prompt: bool = False) -> bool:
    """Return Screen Recording TCC grant status, optionally prompting."""
    if sys.platform != "darwin":
        return False
    try:
        import Quartz

        granted = bool(Quartz.CGPreflightScreenCaptureAccess())
        if prompt and not granted:
            requested = Quartz.CGRequestScreenCaptureAccess()
            if requested is not None:
                granted = bool(requested)
            else:
                granted = bool(Quartz.CGPreflightScreenCaptureAccess())
        return granted
    except Exception:
        return False


def _check_accessibility() -> bool:
    """Return Accessibility TCC grant status via ApplicationServices."""
    if sys.platform != "darwin":
        return False
    try:
        app_services = ctypes.CDLL(_APPLICATION_SERVICES_PATH)
        ax_trusted = app_services.AXIsProcessTrusted
        ax_trusted.argtypes = []
        ax_trusted.restype = ctypes.c_bool
        return bool(ax_trusted())
    except Exception:
        return False


def check_permissions(prompt: bool = False) -> dict[str, bool]:
    """Check macOS Screen Recording and Accessibility permissions.

    Args:
        prompt: If True and Screen Recording is not yet granted, trigger the
            system Screen Recording permission prompt.

    Returns:
        Dictionary with boolean keys ``screen_recording`` and ``accessibility``.
    """
    return {
        "screen_recording": _check_screen_recording(prompt=prompt),
        "accessibility": _check_accessibility(),
    }
