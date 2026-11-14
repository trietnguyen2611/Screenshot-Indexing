"""macOS keyboard shortcut and fixed-coordinate mouse click simulation."""

from __future__ import annotations

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
    "Tab": 48,
    "Escape": 53,
    "Esc": 53,
    "Home": 115,
    "End": 119,
    "Backspace": 51,
    "Delete": 117,
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


def send_keyboard_shortcut(key_code: int = 124) -> bool:
    """Simulate a key press and release using Quartz, with osascript fallback.

    Args:
        key_code: macOS virtual keyCode (default ``124`` = Right Arrow).

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

    try:
        import Quartz

        key_down = Quartz.CGEventCreateKeyboardEvent(None, code, True)
        key_up = Quartz.CGEventCreateKeyboardEvent(None, code, False)
        if key_down is None or key_up is None:
            raise RuntimeError("CGEventCreateKeyboardEvent returned None")
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, key_down)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, key_up)
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


def trigger_page_turn(page_turn_cfg: dict[str, Any]) -> bool:
    """Dispatch configured auto page-turn action (keyboard shortcut or click).

    Args:
        page_turn_cfg: Configuration dict with ``enabled``, ``mode``
            (``"keyboard"`` or ``"click"``), ``key_name`` / ``key_code``, and
            ``click_x`` / ``click_y``.

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
    return send_keyboard_shortcut(resolved_code)
