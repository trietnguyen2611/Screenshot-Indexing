"""macOS system-wide global hotkey listener using Quartz CGEventTap."""

import threading
import time

try:
    import Quartz
except ImportError:
    Quartz = None


# Web KeyboardEvent.code -> macOS CGKeyCode
WEB_CODE_TO_MAC_KEYCODE = {
    "KeyA": 0, "KeyS": 1, "KeyD": 2, "KeyF": 3, "KeyH": 4, "KeyG": 5, "KeyZ": 6,
    "KeyX": 7, "KeyC": 8, "KeyV": 9, "KeyB": 11, "KeyQ": 12, "KeyW": 13, "KeyE": 14,
    "KeyR": 15, "KeyY": 16, "KeyT": 17, "Digit1": 18, "Digit2": 19, "Digit3": 20,
    "Digit4": 21, "Digit6": 22, "Digit5": 23, "Equal": 24, "Digit9": 25, "Digit7": 26,
    "Minus": 27, "Digit8": 28, "Digit0": 29, "BracketRight": 30, "KeyO": 31, "KeyU": 32,
    "BracketLeft": 33, "KeyI": 34, "KeyP": 35, "Enter": 36, "KeyL": 37, "KeyJ": 38,
    "Quote": 39, "KeyK": 40, "Semicolon": 41, "Backslash": 42, "Comma": 43, "Slash": 44,
    "KeyN": 45, "KeyM": 46, "Period": 47, "Tab": 48, "Space": 49, "Backquote": 50,
    "Backspace": 51, "Escape": 53,
    "F1": 122, "F2": 120, "F3": 99, "F4": 118, "F5": 96, "F6": 97,
    "F7": 98, "F8": 100, "F9": 101, "F10": 109, "F11": 103, "F12": 111,
}


def resolve_mac_keycode(code: str) -> int | None:
    """Resolve a Web KeyboardEvent.code string to a macOS virtual keycode."""
    if not isinstance(code, str):
        return None
    return WEB_CODE_TO_MAC_KEYCODE.get(code.strip())


class GlobalHotkeyManager:
    """Listens for a configurable system-wide macOS hotkey and invokes a callback."""

    def __init__(self):
        self._lock = threading.Lock()
        self._shortcut = {
            "code": "KeyR",
            "keycode": 15,
            "ctrl": True,
            "shift": True,
            "alt": False,
            "meta": False,
        }
        self._callback = None
        self._running = False
        self._thread = None
        self._run_loop = None
        self._last_trigger_ts = 0.0

    def set_callback(self, callback) -> None:
        with self._lock:
            self._callback = callback

    def update_shortcut(self, shortcut: dict) -> dict:
        """Update the active global hotkey from a frontend shortcut dict."""
        if not isinstance(shortcut, dict):
            return self.get_shortcut()
        code = str(shortcut.get("code") or "KeyR")
        keycode = resolve_mac_keycode(code)
        if keycode is None:
            return self.get_shortcut()
        with self._lock:
            self._shortcut = {
                "code": code,
                "keycode": keycode,
                "ctrl": bool(shortcut.get("ctrl", False)),
                "shift": bool(shortcut.get("shift", False)),
                "alt": bool(shortcut.get("alt", False)),
                "meta": bool(shortcut.get("meta", False)),
            }
            return dict(self._shortcut)

    def get_shortcut(self) -> dict:
        with self._lock:
            return dict(self._shortcut)

    def start(self) -> bool:
        """Start the background Quartz CGEventTap listener if available."""
        if Quartz is None:
            return False
        with self._lock:
            if self._running:
                return True
            self._running = True
            self._thread = threading.Thread(target=self._run_tap_loop, daemon=True)
            self._thread.start()
            return True

    def stop(self) -> None:
        with self._lock:
            self._running = False
            rl = self._run_loop
            self._run_loop = None
        if Quartz is not None and rl is not None:
            try:
                Quartz.CFRunLoopStop(rl)
            except Exception:
                pass

    def _matches_event(self, keycode: int, flags: int) -> bool:
        with self._lock:
            sc = self._shortcut
            if keycode != sc["keycode"]:
                return False
            ctrl_on = bool(flags & Quartz.kCGEventFlagMaskControl)
            shift_on = bool(flags & Quartz.kCGEventFlagMaskShift)
            alt_on = bool(flags & Quartz.kCGEventFlagMaskAlternate)
            meta_on = bool(flags & Quartz.kCGEventFlagMaskCommand)
            return (
                ctrl_on == sc["ctrl"]
                and shift_on == sc["shift"]
                and alt_on == sc["alt"]
                and meta_on == sc["meta"]
            )

    def _run_tap_loop(self) -> None:
        if Quartz is None:
            return

        def _tap_callback(proxy, event_type, event, refcon):
            try:
                if event_type == Quartz.kCGEventKeyDown:
                    keycode = Quartz.CGEventGetIntegerValueField(event, Quartz.kCGKeyboardEventKeycode)
                    flags = Quartz.CGEventGetFlags(event)
                    if self._matches_event(int(keycode), int(flags)):
                        now = time.monotonic()
                        with self._lock:
                            if now - self._last_trigger_ts < 0.6:
                                return event
                            self._last_trigger_ts = now
                            cb = self._callback
                        if cb is not None:
                            threading.Thread(target=cb, daemon=True).start()
            except Exception:
                pass
            return event

        mask = Quartz.CGEventMaskBit(Quartz.kCGEventKeyDown)
        tap = Quartz.CGEventTapCreate(
            Quartz.kCGSessionEventTap,
            Quartz.kCGHeadInsertEventTap,
            Quartz.kCGEventTapOptionListenOnly,
            mask,
            _tap_callback,
            None,
        )
        if tap is None:
            with self._lock:
                self._running = False
            return

        source = Quartz.CFMachPortCreateRunLoopSource(None, tap, 0)
        rl = Quartz.CFRunLoopGetCurrent()
        with self._lock:
            self._run_loop = rl
        Quartz.CFRunLoopAddSource(rl, source, Quartz.kCFRunLoopCommonModes)
        Quartz.CGEventTapEnable(tap, True)
        Quartz.CFRunLoopRun()


global_hotkey_manager = GlobalHotkeyManager()
