"""macOS TCC permission checks for Screen Recording and Accessibility."""

from __future__ import annotations

import ctypes
import sys

_APPLICATION_SERVICES_PATH = (
    "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
)


_HISERVICES_FRAMEWORK_PATH = (
    "/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework"
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


def _prompt_accessibility_dialog() -> bool | None:
    """Trigger the macOS Accessibility permission prompt via HIServices."""
    try:
        import objc

        ns: dict[str, object] = {}
        bundle = objc.loadBundle(
            "HIServices",
            ns,
            bundle_path=_HISERVICES_FRAMEWORK_PATH,
        )
        objc.loadBundleFunctions(
            bundle, ns, [("AXIsProcessTrustedWithOptions", b"Z@")]
        )
        objc.loadBundleVariables(
            bundle, ns, [("kAXTrustedCheckOptionPrompt", b"@")]
        )
        ax_with_opts = ns.get("AXIsProcessTrustedWithOptions")
        prompt_key = ns.get("kAXTrustedCheckOptionPrompt")
        if callable(ax_with_opts) and prompt_key is not None:
            return bool(ax_with_opts({prompt_key: True}))
    except Exception:
        pass
    return None


def _check_accessibility(prompt: bool = False) -> bool:
    """Return Accessibility TCC grant status via ApplicationServices, optionally prompting."""
    if sys.platform != "darwin":
        return False
    try:
        app_services = ctypes.CDLL(_APPLICATION_SERVICES_PATH)
        ax_trusted = app_services.AXIsProcessTrusted
        ax_trusted.argtypes = []
        ax_trusted.restype = ctypes.c_bool
        granted = bool(ax_trusted())
        if prompt and not granted:
            prompted_result = _prompt_accessibility_dialog()
            if prompted_result is not None:
                granted = prompted_result
            else:
                granted = bool(ax_trusted())
        return granted
    except Exception:
        return False


def check_permissions(prompt: bool = False) -> dict[str, bool]:
    """Check macOS Screen Recording and Accessibility permissions.

    Args:
        prompt: If True and a permission is not yet granted, trigger the
            macOS Screen Recording and Accessibility permission prompts.

    Returns:
        Dictionary with boolean keys ``screen_recording`` and ``accessibility``.
    """
    return {
        "screen_recording": _check_screen_recording(prompt=prompt),
        "accessibility": _check_accessibility(prompt=prompt),
    }
