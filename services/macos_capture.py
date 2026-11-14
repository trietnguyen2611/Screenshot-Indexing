"""macOS fixed-region screen capture, Retina HiDPI math, and timed capture loop."""

from __future__ import annotations

from datetime import datetime, timedelta
import os
import struct
import subprocess
import sys
import tempfile
import threading
import time
from typing import Any, Callable

from services.macos_input import (
    activate_target_app,
    find_target_pid_for_region,
    trigger_page_turn,
)
from services.macos_sound import play_shutter_sound


def get_main_display_info() -> dict[str, int]:
    """Query main display logical bounds in Quartz screen points.

    Returns:
        Dictionary with ``origin_x``, ``origin_y``, ``screen_width``, and
        ``screen_height`` (falling back to ``1440x900`` on error/non-macOS).
    """
    fallback = {
        "origin_x": 0,
        "origin_y": 0,
        "screen_width": 1440,
        "screen_height": 900,
    }
    if sys.platform != "darwin":
        return fallback

    try:
        import Quartz

        bounds = Quartz.CGDisplayBounds(Quartz.CGMainDisplayID())
        width = max(1, int(round(bounds.size.width)))
        height = max(1, int(round(bounds.size.height)))
        return {
            "origin_x": int(round(bounds.origin.x)),
            "origin_y": int(round(bounds.origin.y)),
            "screen_width": width,
            "screen_height": height,
        }
    except Exception:
        return fallback


def read_png_dimensions(path: str) -> tuple[int, int]:
    """Read physical ``(width, height)`` from a PNG file's IHDR header.

    Uses ``struct.unpack`` on bytes ``16:24`` with zero Pillow dependency.
    """
    with open(path, "rb") as fh:
        header = fh.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"Invalid PNG header: {path}")
    width, height = struct.unpack(">II", header[16:24])
    return int(width), int(height)


def convert_canvas_rect_to_logical(
    px_x: float,
    px_y: float,
    px_w: float,
    px_h: float,
    scale_factor: float,
    origin_x: int = 0,
    origin_y: int = 0,
) -> dict[str, int]:
    """Convert physical preview pixel rectangle to Quartz logical screen points."""
    safe_scale = float(scale_factor) if scale_factor and float(scale_factor) > 0 else 1.0
    logical_x = int(round(origin_x + float(px_x) / safe_scale))
    logical_y = int(round(origin_y + float(px_y) / safe_scale))
    logical_w = max(10, int(round(float(px_w) / safe_scale)))
    logical_h = max(10, int(round(float(px_h) / safe_scale)))
    return {
        "x": logical_x,
        "y": logical_y,
        "width": logical_w,
        "height": logical_h,
    }


def convert_canvas_point_to_logical(
    px_x: float,
    px_y: float,
    scale_factor: float,
    origin_x: int = 0,
    origin_y: int = 0,
) -> dict[str, int]:
    """Convert a physical preview pixel point to Quartz logical screen points."""
    safe_scale = float(scale_factor) if scale_factor and float(scale_factor) > 0 else 1.0
    click_x = int(round(origin_x + float(px_x) / safe_scale))
    click_y = int(round(origin_y + float(px_y) / safe_scale))
    return {"click_x": click_x, "click_y": click_y}


def cleanup_preview_file() -> None:
    """Remove temporary full-screen preview PNG if it exists."""
    preview_path = os.path.join(
        tempfile.gettempdir(), "screenshot_indexing_preview.png"
    )
    try:
        if os.path.isfile(preview_path):
            os.remove(preview_path)
    except OSError:
        pass


def _capture_with_quartz(
    output_path: str, region: dict[str, int] | None = None
) -> bool:
    """Capture a PNG screenshot via Quartz CGWindowListCreateImage as fallback."""
    if sys.platform != "darwin":
        return False
    try:
        import AppKit
        import Quartz

        if not hasattr(Quartz, "CGWindowListCreateImage"):
            return False

        if region is None:
            if hasattr(Quartz, "CGDisplayBounds") and hasattr(
                Quartz, "CGMainDisplayID"
            ):
                rect = Quartz.CGDisplayBounds(Quartz.CGMainDisplayID())
            else:
                rect = Quartz.CGRectInfinite
        else:
            rect = Quartz.CGRectMake(
                float(region["x"]),
                float(region["y"]),
                float(region["width"]),
                float(region["height"]),
            )

        cg_img = Quartz.CGWindowListCreateImage(
            rect,
            Quartz.kCGWindowListOptionOnScreenOnly,
            Quartz.kCGNullWindowID,
            Quartz.kCGWindowImageDefault,
        )
        if cg_img is None:
            return False

        rep = AppKit.NSBitmapImageRep.alloc().initWithCGImage_(cg_img)
        if rep is None:
            return False

        png_data = rep.representationUsingType_properties_(
            AppKit.NSBitmapImageFileTypePNG, {}
        )
        if png_data is None:
            return False

        written = bool(png_data.writeToFile_atomically_(output_path, True))
        return (
            written
            and os.path.isfile(output_path)
            and os.path.getsize(output_path) > 0
        )
    except Exception:
        return False


def capture_fullscreen_preview(delay_sec: float = 0.2) -> dict[str, Any]:
    """Capture a full-screen temporary PNG preview and display scaling metadata.

    Args:
        delay_sec: Optional pre-capture delay clamped to ``0.0..5.0`` seconds.

    Returns:
        Dictionary with ``ok: True`` plus ``preview_path``, ``screen_width``,
        ``screen_height``, ``image_width``, ``image_height``, ``scale_factor``,
        ``origin_x``, ``origin_y``, or ``{"ok": False, "error": str}``.
    """
    if sys.platform != "darwin":
        return {"ok": False, "error": "Screen capture is only supported on macOS"}

    try:
        clamped_delay = max(0.0, min(5.0, float(delay_sec)))
    except (TypeError, ValueError):
        clamped_delay = 0.2

    if clamped_delay > 0.0:
        time.sleep(clamped_delay)

    preview_path = os.path.join(
        tempfile.gettempdir(), "screenshot_indexing_preview.png"
    )
    err = ""
    captured = False
    try:
        proc = subprocess.run(
            ["screencapture", "-x", preview_path],
            capture_output=True,
            text=True,
            timeout=15,
        )
        captured = (
            proc.returncode == 0
            and os.path.isfile(preview_path)
            and os.path.getsize(preview_path) > 0
        )
        if not captured:
            err = proc.stderr.strip() or "Failed to capture preview screenshot"
    except Exception as exc:
        err = str(exc)

    if not captured:
        captured = _capture_with_quartz(preview_path, region=None)

    if not captured:
        if os.path.isfile(preview_path) and os.path.getsize(preview_path) == 0:
            try:
                os.remove(preview_path)
            except OSError:
                pass
        return {"ok": False, "error": err or "Failed to capture preview screenshot"}

    try:
        image_width, image_height = read_png_dimensions(preview_path)
        display = get_main_display_info()
        scale_factor = round(float(image_width) / float(display["screen_width"]), 4)
        return {
            "ok": True,
            "preview_path": preview_path,
            "screen_width": display["screen_width"],
            "screen_height": display["screen_height"],
            "image_width": image_width,
            "image_height": image_height,
            "scale_factor": scale_factor,
            "origin_x": display["origin_x"],
            "origin_y": display["origin_y"],
        }
    except Exception as exc:
        return {"ok": False, "error": str(exc)}


def generate_screenshot_filename(
    save_folder: str, now: datetime | None = None
) -> str:
    """Generate a collision-free macOS-compatible screenshot filename.

    Produces names matching ``is_screenshot_file()`` (starts with
    ``"Screenshot "``) and ``get_sort_key()`` (ends with ``HH.MM.SS.png``)
    while advancing timestamps or adding a prefix counter to prevent collisions.
    """
    base_dt = now if now is not None else datetime.now()

    # Prefer advancing +1s within the same date so chronological sort keys stay strictly increasing.
    for offset in range(0, 60):
        candidate_dt = base_dt + timedelta(seconds=offset)
        if candidate_dt.date() != base_dt.date():
            break
        candidate = (
            f"Screenshot {candidate_dt.strftime('%Y-%m-%d')} "
            f"at {candidate_dt.strftime('%H.%M.%S')}.png"
        )
        if not os.path.exists(os.path.join(save_folder, candidate)):
            return candidate

    date_str = base_dt.strftime("%Y-%m-%d")
    time_str = base_dt.strftime("%H.%M.%S")
    counter = 2
    while True:
        candidate = f"Screenshot {date_str} ({counter}) at {time_str}.png"
        if not os.path.exists(os.path.join(save_folder, candidate)):
            return candidate
        counter += 1


def capture_region_once(
    save_folder: str,
    region: dict[str, Any],
    sound_enabled: bool = True,
) -> dict[str, Any]:
    """Capture a single fixed logical screen region into ``save_folder``.

    Args:
        save_folder: Destination folder path.
        region: Mapping containing ``x``, ``y``, ``width``, and ``height``.
        sound_enabled: Whether to play non-blocking macOS shutter sound.

    Returns:
        ``{"ok": True, "filename": str, "path": str}`` or
        ``{"ok": False, "error": str}``.
    """
    if sys.platform != "darwin":
        return {"ok": False, "error": "Screen capture is only supported on macOS"}

    if not save_folder or not str(save_folder).strip():
        return {"ok": False, "error": "Save folder is required"}

    try:
        os.makedirs(save_folder, exist_ok=True)
    except OSError as exc:
        return {"ok": False, "error": str(exc)}

    try:
        x = int(round(region["x"]))
        y = int(round(region["y"]))
        w = int(round(region["width"]))
        h = int(round(region["height"]))
    except (KeyError, TypeError, ValueError):
        return {"ok": False, "error": "Invalid capture region"}

    if w <= 0 or h <= 0:
        return {"ok": False, "error": "Invalid capture region dimensions"}

    filename = generate_screenshot_filename(save_folder)
    full_path = os.path.join(save_folder, filename)

    err = ""
    captured = False
    try:
        proc = subprocess.run(
            ["screencapture", "-x", "-R", f"{x},{y},{w},{h}", full_path],
            capture_output=True,
            text=True,
            timeout=15,
        )
        captured = (
            proc.returncode == 0
            and os.path.isfile(full_path)
            and os.path.getsize(full_path) > 0
        )
        if not captured:
            err = proc.stderr.strip() or "Screen capture failed"
    except Exception as exc:
        err = str(exc)

    if not captured:
        captured = _capture_with_quartz(
            full_path,
            region={"x": x, "y": y, "width": w, "height": h},
        )

    if not captured:
        if os.path.isfile(full_path) and os.path.getsize(full_path) == 0:
            try:
                os.remove(full_path)
            except OSError:
                pass
        return {"ok": False, "error": err or "Screen capture failed"}

    play_shutter_sound(sound_enabled)
    return {"ok": True, "filename": filename, "path": full_path}


class CaptureController:
    """Thread-safe controller managing timed auto-capture & page-turn loops."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._stop_event: threading.Event | None = None
        self._thread: threading.Thread | None = None
        self._running = False
        self._phase = "idle"
        self._countdown_remaining = 0
        self._captured_count = 0
        self._max_shots = 0
        self._interval_sec: int | float = 3
        self._save_folder = ""
        self._last_file: str | None = None
        self._captured_files: list[str] = []
        self._last_error: str | None = None

    def _snapshot_locked(self) -> dict[str, Any]:
        return {
            "running": self._running,
            "phase": self._phase,
            "countdown_remaining": self._countdown_remaining,
            "captured_count": self._captured_count,
            "max_shots": self._max_shots,
            "interval_sec": self._interval_sec,
            "save_folder": self._save_folder,
            "last_file": self._last_file,
            "captured_files": list(self._captured_files),
            "last_error": self._last_error,
        }

    def get_status(self) -> dict[str, Any]:
        """Return a thread-safe snapshot of the current capture session."""
        with self._lock:
            return self._snapshot_locked()

    def start(
        self,
        config: dict[str, Any],
        on_shot_callback: Callable[[str, str], None] | None = None,
    ) -> dict[str, Any]:
        """Validate configuration and start the background timed capture loop."""
        with self._lock:
            if self._running:
                return {
                    "ok": False,
                    "error": "already_running",
                    "status": self._snapshot_locked(),
                }
            prev_thread = self._thread

        if (
            prev_thread is not None
            and prev_thread.is_alive()
            and prev_thread is not threading.current_thread()
        ):
            prev_thread.join(timeout=1.0)

        raw_folder = str((config or {}).get("save_folder", "")).strip()
        save_folder = os.path.expanduser(raw_folder) if raw_folder else ""
        if not save_folder:
            return {
                "ok": False,
                "error": "missing_save_folder",
                "status": self.get_status(),
            }

        try:
            os.makedirs(save_folder, exist_ok=True)
        except OSError as exc:
            return {
                "ok": False,
                "error": str(exc),
                "status": self.get_status(),
            }

        raw_region = (config or {}).get("region") or {}
        try:
            region = {
                "x": int(round(float(raw_region.get("x", 0)))),
                "y": int(round(float(raw_region.get("y", 0)))),
                "width": int(round(float(raw_region.get("width", 0)))),
                "height": int(round(float(raw_region.get("height", 0)))),
            }
        except (TypeError, ValueError):
            return {
                "ok": False,
                "error": "invalid_region",
                "status": self.get_status(),
            }

        if region["width"] < 10 or region["height"] < 10:
            return {
                "ok": False,
                "error": "invalid_region",
                "status": self.get_status(),
            }

        try:
            raw_interval = float((config or {}).get("interval_sec", 3))
        except (TypeError, ValueError):
            raw_interval = 3.0
        clamped_interval = max(1.0, min(10.0, raw_interval))
        interval_sec: int | float = (
            int(clamped_interval)
            if clamped_interval.is_integer()
            else clamped_interval
        )

        try:
            raw_countdown = float((config or {}).get("countdown_sec", 3))
        except (TypeError, ValueError):
            raw_countdown = 3.0
        countdown_sec = max(0, min(10, int(round(raw_countdown))))

        try:
            raw_max = int((config or {}).get("max_shots", 0) or 0)
        except (TypeError, ValueError):
            raw_max = 0
        max_shots = max(0, raw_max)

        sound_enabled = bool((config or {}).get("sound_enabled", True))
        page_turn_cfg = dict((config or {}).get("page_turn") or {})

        stop_event = threading.Event()
        with self._lock:
            if self._running:
                return {
                    "ok": False,
                    "error": "already_running",
                    "status": self._snapshot_locked(),
                }
            self._stop_event = stop_event
            self._running = True
            self._phase = "countdown" if countdown_sec > 0 else "capturing"
            self._countdown_remaining = countdown_sec
            self._captured_count = 0
            self._max_shots = max_shots
            self._interval_sec = interval_sec
            self._save_folder = save_folder
            self._last_file = None
            self._captured_files = []
            self._last_error = None

            thread = threading.Thread(
                target=self._run_loop,
                args=(
                    stop_event,
                    save_folder,
                    region,
                    interval_sec,
                    countdown_sec,
                    max_shots,
                    sound_enabled,
                    page_turn_cfg,
                    on_shot_callback,
                ),
                daemon=True,
            )
            self._thread = thread
            snapshot = self._snapshot_locked()

        thread.start()
        return {"ok": True, "status": snapshot}

    def stop(self) -> dict[str, Any]:
        """Abort the active capture loop immediately and return updated status."""
        with self._lock:
            was_running = self._running
            stop_event = self._stop_event
            thread = self._thread
            if stop_event is not None:
                stop_event.set()

        if (
            thread is not None
            and thread.is_alive()
            and thread is not threading.current_thread()
        ):
            thread.join(timeout=1.5)

        with self._lock:
            self._running = False
            self._countdown_remaining = 0
            if (was_running or self._phase in ("countdown", "capturing")) and (
                self._phase not in ("completed", "error")
            ):
                self._phase = "stopped"
            return self._snapshot_locked()

    def reset(self) -> dict[str, Any]:
        """Stop any active capture loop and reset controller session state to idle."""
        self.stop()
        with self._lock:
            self._phase = "idle"
            self._countdown_remaining = 0
            self._captured_count = 0
            self._max_shots = 0
            self._interval_sec = 3
            self._save_folder = ""
            self._last_file = None
            self._captured_files = []
            self._last_error = None
            return self._snapshot_locked()

    def _run_loop(
        self,
        stop_event: threading.Event,
        save_folder: str,
        region: dict[str, int],
        interval_sec: int | float,
        countdown_sec: int,
        max_shots: int,
        sound_enabled: bool,
        page_turn_cfg: dict[str, Any],
        on_shot_callback: Callable[[str, str], None] | None,
    ) -> None:
        try:
            initial_target_pid = find_target_pid_for_region(region)

            for remaining in range(countdown_sec, 0, -1):
                with self._lock:
                    if stop_event.is_set():
                        break
                    self._phase = "countdown"
                    self._countdown_remaining = remaining
                if stop_event.wait(1.0):
                    break

            if stop_event.is_set():
                with self._lock:
                    self._countdown_remaining = 0
                    self._running = False
                    if self._phase not in ("completed", "error"):
                        self._phase = "stopped"
                return

            with self._lock:
                self._countdown_remaining = 0
                self._phase = "capturing"

            target_pid = find_target_pid_for_region(region) or initial_target_pid
            if target_pid:
                activate_target_app(target_pid)

            while not stop_event.is_set():
                shot = capture_region_once(
                    save_folder, region, sound_enabled=sound_enabled
                )
                if not shot.get("ok"):
                    with self._lock:
                        self._last_error = str(
                            shot.get("error") or "Screen capture failed"
                        )
                        self._phase = "error"
                        self._running = False
                    return

                filename = str(shot["filename"])
                with self._lock:
                    self._captured_count += 1
                    self._last_file = filename
                    self._captured_files.append(filename)
                    captured_count = self._captured_count

                if on_shot_callback is not None:
                    try:
                        on_shot_callback(save_folder, filename)
                    except Exception:
                        pass

                if max_shots > 0 and captured_count >= max_shots:
                    with self._lock:
                        self._phase = "completed"
                        self._running = False
                    return

                if stop_event.is_set():
                    break

                if page_turn_cfg.get("enabled", True):
                    loop_target = find_target_pid_for_region(region) or target_pid
                    if loop_target:
                        target_pid = loop_target
                    turned = trigger_page_turn(page_turn_cfg, target_pid=target_pid)
                    if not turned:
                        with self._lock:
                            if not self._last_error:
                                self._last_error = (
                                    "Auto page-turn blocked: grant Accessibility "
                                    "permission in System Settings"
                                )

                if stop_event.wait(timeout=float(interval_sec)):
                    break

            with self._lock:
                self._running = False
                if self._phase not in ("completed", "error"):
                    self._phase = "stopped"
        except Exception as exc:
            with self._lock:
                self._last_error = str(exc)
                self._phase = "error"
                self._running = False


capture_controller = CaptureController()
