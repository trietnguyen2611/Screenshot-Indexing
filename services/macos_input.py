"""macOS keyboard shortcut and fixed-coordinate mouse click simulation."""

from __future__ import annotations

import os
import subprocess
import sys
import time
from typing import Any

# Standard macOS ANSI virtual keyCodes (HIToolbox/Events.h) mapped from JS e.key / e.code
# and human-friendly key names. Never use browser DOM keyCodes here.
KEY_CODE_MAP: dict[str, int] = {
    "ArrowRight": 124,
    "Right": 124,
    "ArrowLeft": 123,
    "Left": 123,
    "ArrowDown": 125,
    "Down": 125,
    "ArrowUp": 126,
    "Up": 126,
    "Space": 49,
    " ": 49,
    "Spacebar": 49,
    "PageDown": 121,
    "PageUp": 116,
    "Enter": 36,
    "Return": 36,
    "NumpadEnter": 36,
    "Tab": 48,
    "Escape": 53,
    "Esc": 53,
    "Home": 115,
    "End": 119,
    "Backspace": 51,
    "Delete": 117,
    "Period": 47,
    ".": 47,
    "Comma": 43,
    ",": 43,
    "Slash": 44,
    "/": 44,
    "Semicolon": 41,
    ";": 41,
    "Quote": 39,
    "'": 39,
    "BracketLeft": 33,
    "[": 33,
    "BracketRight": 30,
    "]": 30,
    "Backslash": 42,
    "\\": 42,
    "Minus": 27,
    "-": 27,
    "Equal": 24,
    "=": 24,
    "Backquote": 50,
    "`": 50,
    "F1": 122,
    "F2": 120,
    "F3": 99,
    "F4": 118,
    "F5": 96,
    "F6": 97,
    "F7": 98,
    "F8": 100,
    "F9": 101,
    "F10": 109,
    "F11": 103,
    "F12": 111,
}

_LETTER_KEY_CODES: dict[str, int] = {
    "a": 0,
    "s": 1,
    "d": 2,
    "f": 3,
    "h": 4,
    "g": 5,
    "z": 6,
    "x": 7,
    "c": 8,
    "v": 9,
    "b": 11,
    "q": 12,
    "w": 13,
    "e": 14,
    "r": 15,
    "y": 16,
    "t": 17,
    "o": 31,
    "u": 32,
    "i": 34,
    "p": 35,
    "l": 37,
    "j": 38,
    "k": 40,
    "n": 45,
    "m": 46,
}

_DIGIT_KEY_CODES: dict[str, int] = {
    "1": 18,
    "2": 19,
    "3": 20,
    "4": 21,
    "6": 22,
    "5": 23,
    "9": 25,
    "7": 26,
    "8": 28,
    "0": 29,
}

for _ch, _code in _LETTER_KEY_CODES.items():
    KEY_CODE_MAP[_ch] = _code
    KEY_CODE_MAP[_ch.upper()] = _code
    KEY_CODE_MAP[f"Key{_ch.upper()}"] = _code

for _digit, _code in _DIGIT_KEY_CODES.items():
    KEY_CODE_MAP[_digit] = _code
    KEY_CODE_MAP[f"Digit{_digit}"] = _code

_KEY_CODE_LOWER_MAP: dict[str, int] = {k.lower(): v for k, v in KEY_CODE_MAP.items()}


def resolve_key_code(key_name: str = "ArrowRight", key_code: int | None = None) -> int:
    """Resolve a key name or explicit virtual keyCode to a macOS virtual keyCode.

    Prefers lookup of ``key_name`` in ``KEY_CODE_MAP`` (exact match first, then
    case-insensitive fallback), falling back to ``key_code`` when non-negative,
    and finally defaulting to Right Arrow (``124``).
    """
    if isinstance(key_name, str) and key_name != "":
        if key_name in KEY_CODE_MAP:
            return KEY_CODE_MAP[key_name]
        stripped = key_name.strip()
        if stripped in KEY_CODE_MAP:
            return KEY_CODE_MAP[stripped]
        lowered = key_name.lower()
        if lowered in _KEY_CODE_LOWER_MAP:
            return _KEY_CODE_LOWER_MAP[lowered]
        if stripped.lower() in _KEY_CODE_LOWER_MAP:
            return _KEY_CODE_LOWER_MAP[stripped.lower()]

    if key_code is not None and not isinstance(key_code, bool):
        try:
            parsed = int(key_code)
            if parsed >= 0:
                return parsed
        except (TypeError, ValueError):
            pass

    return 124


_IGNORED_WINDOW_OWNERS = {
    "Window Server",
    "WindowManager",
    "Dock",
    "Control Center",
    "Notification Center",
    "Screenshot Indexing",
}

_MODIFIER_CLEAR_MASK = 0x100000 | 0x20000 | 0x80000 | 0x40000


def _is_accessibility_trusted() -> bool:
    """Return True if Accessibility TCC is granted (or running against a mocked Quartz module)."""
    quartz_mod = sys.modules.get("Quartz")
    if quartz_mod is not None and not hasattr(quartz_mod, "CGWindowListCopyWindowInfo"):
        return True
    try:
        from services.macos_permissions import _check_accessibility

        return _check_accessibility(prompt=False)
    except Exception:
        return False


def find_target_pid_for_region(region: dict[str, Any] | None = None) -> int | None:
    """Find the PID of the frontmost external window overlapping ``region``."""
    if sys.platform != "darwin":
        return None
    try:
        import Quartz

        if not hasattr(Quartz, "CGWindowListCopyWindowInfo"):
            return None

        wins = Quartz.CGWindowListCopyWindowInfo(
            Quartz.kCGWindowListOptionOnScreenOnly
            | Quartz.kCGWindowListExcludeDesktopElements,
            Quartz.kCGNullWindowID,
        )
        if not wins:
            return None

        my_pid = os.getpid()
        has_region = isinstance(region, dict) and float(region.get("width", 0)) > 0 and float(region.get("height", 0)) > 0
        rx1 = float(region.get("x", 0)) if has_region else 0.0
        ry1 = float(region.get("y", 0)) if has_region else 0.0
        rx2 = rx1 + float(region.get("width", 0)) if has_region else 0.0
        ry2 = ry1 + float(region.get("height", 0)) if has_region else 0.0

        fallback_pid: int | None = None
        for win in wins:
            if win.get("kCGWindowLayer", -1) != 0:
                continue
            pid = win.get("kCGWindowOwnerPID")
            owner = str(win.get("kCGWindowOwnerName") or "")
            if not pid or int(pid) == my_pid or owner in _IGNORED_WINDOW_OWNERS:
                continue
            pid_int = int(pid)
            if fallback_pid is None:
                fallback_pid = pid_int

            if not has_region:
                return pid_int

            bounds = win.get("kCGWindowBounds") or {}
            wx1 = float(bounds.get("X", 0))
            wy1 = float(bounds.get("Y", 0))
            wx2 = wx1 + float(bounds.get("Width", 0))
            wy2 = wy1 + float(bounds.get("Height", 0))
            if min(rx2, wx2) > max(rx1, wx1) and min(ry2, wy2) > max(ry1, wy1):
                return pid_int

        return fallback_pid
    except Exception:
        return None


def activate_target_app(target_pid: int | None) -> bool:
    """Bring the application owning ``target_pid`` to the foreground if needed."""
    if sys.platform != "darwin" or not target_pid:
        return False
    try:
        pid = int(target_pid)
        if pid <= 0 or pid == os.getpid():
            return False

        import AppKit

        ws = AppKit.NSWorkspace.sharedWorkspace()
        front = ws.frontmostApplication() if ws is not None else None
        if front is not None and int(front.processIdentifier()) == pid:
            return True

        running_app = AppKit.NSRunningApplication.runningApplicationWithProcessIdentifier_(pid)
        if running_app is None:
            return False

        # NSApplicationActivateIgnoringOtherApps = 1 << 1 = 2
        activated = bool(running_app.activateWithOptions_(2))
        if activated:
            time.sleep(0.06)
        return activated
    except Exception:
        return False


def send_keyboard_shortcut(key_code: int = 124, target_pid: int | None = None) -> bool:
    """Simulate a key press and release using Quartz, with osascript fallback.

    Args:
        key_code: macOS virtual keyCode (default ``124`` = Right Arrow).
        target_pid: Optional PID of the target application to focus before sending.

    Returns:
        True if the keyboard event was posted successfully, False otherwise.
    """
    if sys.platform != "darwin":
        return False

    try:
        code = int(key_code)
        if code < 0:
            return False
    except (TypeError, ValueError):
        return False

    if target_pid:
        activate_target_app(target_pid)

    try:
        import Quartz

        source = (
            Quartz.CGEventSourceCreate(Quartz.kCGEventSourceStateHIDSystemState)
            if hasattr(Quartz, "CGEventSourceCreate")
            and hasattr(Quartz, "kCGEventSourceStateHIDSystemState")
            else None
        )
        key_down = Quartz.CGEventCreateKeyboardEvent(source, code, True)
        key_up = Quartz.CGEventCreateKeyboardEvent(source, code, False)
        if key_down is None or key_up is None:
            raise RuntimeError("CGEventCreateKeyboardEvent returned None")

        if hasattr(Quartz, "CGEventGetFlags") and hasattr(Quartz, "CGEventSetFlags"):
            for ev in (key_down, key_up):
                flags = int(Quartz.CGEventGetFlags(ev))
                Quartz.CGEventSetFlags(ev, flags & ~_MODIFIER_CLEAR_MASK)

        Quartz.CGEventPost(Quartz.kCGHIDEventTap, key_down)
        time.sleep(0.035)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, key_up)

        if _is_accessibility_trusted():
            return True
    except Exception:
        pass

    try:
        proc = subprocess.run(
            [
                "osascript",
                "-e",
                f'tell application "System Events" to key code {code}',
            ],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return proc.returncode == 0
    except Exception:
        return False


def send_mouse_click(click_x: float, click_y: float) -> bool:
    """Simulate a left mouse click at logical Quartz screen coordinates.

    Args:
        click_x: Logical horizontal screen point.
        click_y: Logical vertical screen point (top-left origin).

    Returns:
        True if the click events were posted successfully, False otherwise.
    """
    if sys.platform != "darwin":
        return False

    try:
        import Quartz

        point = Quartz.CGPointMake(float(click_x), float(click_y))
        move_ev = Quartz.CGEventCreateMouseEvent(
            None, Quartz.kCGEventMouseMoved, point, Quartz.kCGMouseButtonLeft
        )
        down_ev = Quartz.CGEventCreateMouseEvent(
            None, Quartz.kCGEventLeftMouseDown, point, Quartz.kCGMouseButtonLeft
        )
        up_ev = Quartz.CGEventCreateMouseEvent(
            None, Quartz.kCGEventLeftMouseUp, point, Quartz.kCGMouseButtonLeft
        )
        if move_ev is None or down_ev is None or up_ev is None:
            return False

        Quartz.CGEventPost(Quartz.kCGHIDEventTap, move_ev)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, down_ev)
        time.sleep(0.03)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, up_ev)
        return True
    except Exception:
        return False


def trigger_page_turn(page_turn_cfg: dict[str, Any], target_pid: int | None = None) -> bool:
    """Dispatch configured auto page-turn action (keyboard shortcut or click).

    Args:
        page_turn_cfg: Configuration dict with ``enabled``, ``mode``
            (``"keyboard"`` or ``"click"``), ``key_name`` / ``key_code``, and
            ``click_x`` / ``click_y``.
        target_pid: Optional PID of the target application window to focus.

    Returns:
        True if the page-turn event was sent, False if disabled or failed.
    """
    if not isinstance(page_turn_cfg, dict) or not page_turn_cfg.get("enabled", True):
        return False

    mode = page_turn_cfg.get("mode", "keyboard")
    if mode == "click":
        return send_mouse_click(
            page_turn_cfg.get("click_x", 500),
            page_turn_cfg.get("click_y", 500),
        )

    resolved_code = resolve_key_code(
        page_turn_cfg.get("key_name", "ArrowRight"),
        page_turn_cfg.get("key_code"),
    )
    return send_keyboard_shortcut(resolved_code, target_pid=target_pid)
