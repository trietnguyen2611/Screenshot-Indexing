"""Comprehensive test suite for Screenshot-Indexing backend, macOS automation, i18n, and CI packaging."""

from __future__ import annotations

from datetime import datetime
import json
import os
import pathlib
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import threading
import time
import types
import unicodedata
import unittest
from unittest import mock

PROJECT_ROOT = pathlib.Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import app as app_module  # noqa: E402
from services import (  # noqa: E402
    config_store,
    macos_capture,
    macos_input,
    macos_overlay,
    macos_permissions,
    macos_sound,
)


def _make_minimal_png(width: int = 3024, height: int = 1964) -> bytes:
    """Build minimal valid PNG bytes containing an IHDR chunk with given dimensions."""
    ihdr_data = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    ihdr_chunk = (
        struct.pack(">I", len(ihdr_data))
        + b"IHDR"
        + ihdr_data
        + struct.pack(">I", 0)
    )
    iend_chunk = struct.pack(">I", 0) + b"IEND" + struct.pack(">I", 0)
    return b"\x89PNG\r\n\x1a\n" + ihdr_chunk + iend_chunk


class BaseIsolatedTestCase(unittest.TestCase):
    """Base test case isolating config file path and Flask app state."""

    def setUp(self) -> None:
        self.tmpdir = tempfile.TemporaryDirectory()
        self.tmp_path = pathlib.Path(self.tmpdir.name)
        self.config_path = self.tmp_path / "app_support" / "config.json"

        self._orig_config_env = os.environ.get("SCREENSHOT_INDEXING_CONFIG_PATH")
        os.environ["SCREENSHOT_INDEXING_CONFIG_PATH"] = str(self.config_path)

        app_module.state["folder_path"] = ""
        app_module.state["files"] = []
        app_module.app.config["TESTING"] = True
        self.client = app_module.app.test_client()

    def tearDown(self) -> None:
        try:
            macos_capture.capture_controller.stop()
        except Exception:
            pass

        if self._orig_config_env is None:
            os.environ.pop("SCREENSHOT_INDEXING_CONFIG_PATH", None)
        else:
            os.environ["SCREENSHOT_INDEXING_CONFIG_PATH"] = self._orig_config_env

        self.tmpdir.cleanup()


class TestExistingEndpointsAndRename(BaseIsolatedTestCase):
    """Verify core indexing routes, NFC/NFD Unicode handling, and safe two-step rename."""

    def test_index_and_version_endpoints(self) -> None:
        resp = self.client.get("/")
        self.assertEqual(resp.status_code, 200)
        html = resp.get_data(as_text=True)
        self.assertIn("Screenshot Indexing", html)
        self.assertIn('id="tab-btn-capture"', html)
        self.assertIn('id="header-lang-select"', html)
        self.assertIn('id="header-theme-toggle-btn"', html)
        self.assertIn('id="key-recorder-input"', html)
        self.assertIn('id="capture-canvas"', html)
        self.assertNotIn('id="lang-select"', html)
        self.assertNotIn('id="theme-toggle-btn"', html)
        self.assertNotIn('id="page-turn-key-preset"', html)
        self.assertNotIn('id="btn-pt-mode-click"', html)
        self.assertNotIn('id="live-capture-view"', html)

        ver_resp = self.client.get("/api/version")
        self.assertEqual(ver_resp.status_code, 200)
        self.assertEqual(ver_resp.get_json(), {"version": app_module.VERSION})

    def test_browse_directory_success_and_bilingual_errors(self) -> None:
        sub_a = self.tmp_path / "alpha"
        sub_b = self.tmp_path / "beta"
        hidden = self.tmp_path / ".hidden"
        sub_a.mkdir()
        sub_b.mkdir()
        hidden.mkdir()
        (self.tmp_path / "file.txt").write_text("x", encoding="utf-8")

        res = self.client.post(
            "/api/browse", json={"path": str(self.tmp_path), "lang": "en"}
        ).get_json()
        self.assertTrue(res["ok"])
        self.assertEqual(res["current"], str(self.tmp_path))
        self.assertEqual(res["dirs"], ["alpha", "beta"])

        missing_en = self.client.post(
            "/api/browse",
            json={"path": str(self.tmp_path / "does_not_exist"), "lang": "en"},
        ).get_json()
        missing_vi = self.client.post(
            "/api/browse",
            json={"path": str(self.tmp_path / "does_not_exist"), "lang": "vi"},
        ).get_json()
        self.assertFalse(missing_en["ok"])
        self.assertFalse(missing_vi["ok"])
        self.assertEqual(missing_en["message"], "Path does not exist")
        self.assertEqual(missing_vi["message"], "Đường dẫn không tồn tại")

    def test_scan_supports_nfc_nfd_vietnamese_and_chronological_sort(self) -> None:
        shots_dir = self.tmp_path / "shots"
        shots_dir.mkdir()

        # Intentionally create in reverse chronological order and mixed NFC/NFD
        name_3 = "Screenshot 2026-11-14 at 10.00.03.png"
        name_1_nfc = unicodedata.normalize(
            "NFC", "Ảnh màn hình 2026-11-14 lúc 10.00.01.png"
        )
        name_2_nfd = unicodedata.normalize(
            "NFD", "Ảnh màn hình 2026-11-14 lúc 10.00.02.png"
        )
        name_4 = "anh man hinh 2026-11-14 luc 10.00.04.png"
        ignored_other = "photo_10.00.05.png"
        ignored_ext = "Screenshot 2026-11-14 at 10.00.06.jpg"

        for fname in (name_3, name_1_nfc, name_2_nfd, name_4, ignored_other, ignored_ext):
            (shots_dir / fname).write_bytes(_make_minimal_png(100, 100))

        # Check directly on helper for both NFC and NFD forms
        self.assertTrue(app_module.is_screenshot_file(name_1_nfc))
        self.assertTrue(app_module.is_screenshot_file(name_2_nfd))
        self.assertTrue(app_module.is_screenshot_file(name_4))
        self.assertFalse(app_module.is_screenshot_file(ignored_other))
        self.assertFalse(app_module.is_screenshot_file(ignored_ext))

        res = self.client.post(
            "/api/scan", json={"folder": str(shots_dir), "lang": "en"}
        ).get_json()
        self.assertTrue(res["ok"])
        self.assertEqual(res["count"], 4)
        returned_names = [item["name"] for item in res["files"]]
        # Compare normalized NFC because macOS APFS normalizes filenames to NFD on disk
        returned_nfc = [unicodedata.normalize("NFC", n) for n in returned_names]
        self.assertEqual(
            returned_nfc,
            [
                unicodedata.normalize("NFC", name_1_nfc),
                unicodedata.normalize("NFC", name_2_nfd),
                name_3,
                name_4,
            ],
        )

    def test_rename_two_step_collision_safety_and_existing_guard(self) -> None:
        shots_dir = self.tmp_path / "rename_dir"
        shots_dir.mkdir()

        f1 = "Screenshot 2026-11-14 at 09.00.01.png"
        f2 = "Screenshot 2026-11-14 at 09.00.02.png"
        (shots_dir / f1).write_bytes(b"first-content")
        (shots_dir / f2).write_bytes(b"second-content")
        # Pre-existing target 2.png should NOT be overwritten by step 2 guard
        (shots_dir / "2.png").write_bytes(b"do-not-overwrite")

        scan_res = self.client.post(
            "/api/scan", json={"folder": str(shots_dir), "lang": "en"}
        ).get_json()
        self.assertEqual(scan_res["count"], 2)

        rename_res = self.client.post(
            "/api/rename", json={"start": 1, "end": 2, "lang": "en"}
        ).get_json()
        self.assertTrue(rename_res["ok"])
        self.assertEqual(rename_res["total"], 2)
        self.assertEqual(rename_res["success"], 1)

        self.assertEqual((shots_dir / "1.png").read_bytes(), b"first-content")
        self.assertEqual((shots_dir / "2.png").read_bytes(), b"do-not-overwrite")
        # Second file remains safely in temp name rather than clobbering existing 2.png
        self.assertTrue((shots_dir / "__temp_rename_2.png").is_file())

    def test_get_image_endpoint(self) -> None:
        shots_dir = self.tmp_path / "imgs"
        shots_dir.mkdir()
        (shots_dir / "Screenshot 2026-11-14 at 10.00.01.png").write_bytes(
            _make_minimal_png(100, 100)
        )

        # No folder scanned yet -> 404
        resp_missing = self.client.get(
            "/api/image?name=Screenshot+2026-11-14+at+10.00.01.png"
        )
        self.assertEqual(resp_missing.status_code, 404)

        self.client.post("/api/scan", json={"folder": str(shots_dir), "lang": "en"})
        resp_ok = self.client.get(
            "/api/image?name=Screenshot+2026-11-14+at+10.00.01.png"
        )
        self.assertEqual(resp_ok.status_code, 200)
        resp_ok.close()


class TestConfigStore(BaseIsolatedTestCase):
    """Verify persistent config normalization, clamping, and deep merge."""

    def test_custom_path_and_defaults(self) -> None:
        self.assertEqual(config_store.get_config_path(), str(self.config_path))
        cfg = config_store.load_config()
        self.assertEqual(cfg["interval_sec"], 3)
        self.assertEqual(cfg["countdown_sec"], 3)
        self.assertEqual(cfg["max_shots"], 0)
        self.assertEqual(cfg["region"], {"x": 100, "y": 100, "width": 800, "height": 600})
        self.assertTrue(cfg["sound_enabled"])

    def test_clamping_and_deep_merge(self) -> None:
        saved = config_store.save_config(
            {
                "save_folder": "~/Desktop/MyShots",
                "interval_sec": 99,
                "countdown_sec": -4,
                "max_shots": -10,
                "region": {"x": 50, "width": 3, "height": 5},
                "page_turn": {"mode": "click", "click_x": 777},
            }
        )
        self.assertEqual(saved["save_folder"], os.path.expanduser("~/Desktop/MyShots"))
        self.assertEqual(saved["interval_sec"], 10)
        self.assertEqual(saved["countdown_sec"], 0)
        self.assertEqual(saved["max_shots"], 0)
        self.assertEqual(saved["region"]["x"], 50)
        self.assertEqual(saved["region"]["y"], 100)  # preserved default
        self.assertEqual(saved["region"]["width"], 10)
        self.assertEqual(saved["region"]["height"], 10)
        self.assertEqual(saved["page_turn"]["mode"], "click")
        self.assertEqual(saved["page_turn"]["click_x"], 777)
        self.assertEqual(saved["page_turn"]["click_y"], 500)

        # Second partial save preserves previous fields and clamps low interval
        saved2 = config_store.save_config(
            {"interval_sec": 0, "countdown_sec": 25, "page_turn": {"key_name": " "}}
        )
        self.assertEqual(saved2["interval_sec"], 1)
        self.assertEqual(saved2["countdown_sec"], 10)
        self.assertEqual(saved2["region"]["x"], 50)
        self.assertEqual(saved2["page_turn"]["click_x"], 777)
        self.assertEqual(saved2["page_turn"]["key_name"], " ")

        # Verify persisted JSON on disk matches
        raw_disk = json.loads(self.config_path.read_text(encoding="utf-8"))
        self.assertEqual(raw_disk["interval_sec"], 1)

        # Verify reset_config deletes persisted config file and restores defaults
        reset = config_store.reset_config()
        self.assertFalse(self.config_path.exists())
        self.assertEqual(reset["save_folder"], "")
        self.assertEqual(reset["interval_sec"], 3)
        self.assertEqual(reset["max_shots"], 0)


class TestMacOSInput(unittest.TestCase):
    """Verify keyCode mapping and mocked keyboard/click page-turn actions."""

    def test_key_code_map_and_resolve(self) -> None:
        self.assertEqual(macos_input.resolve_key_code("ArrowRight"), 124)
        self.assertEqual(macos_input.resolve_key_code("arrowright"), 124)
        self.assertEqual(macos_input.resolve_key_code("Space"), 49)
        self.assertEqual(macos_input.resolve_key_code(" "), 49)
        self.assertEqual(macos_input.resolve_key_code("PageDown"), 121)
        self.assertEqual(macos_input.resolve_key_code("Enter"), 36)
        self.assertEqual(macos_input.resolve_key_code("a"), 0)
        self.assertEqual(macos_input.resolve_key_code("KeyA"), 0)
        self.assertEqual(macos_input.resolve_key_code("."), 47)
        self.assertEqual(macos_input.resolve_key_code("Period"), 47)
        self.assertEqual(macos_input.resolve_key_code("F1"), 122)
        self.assertEqual(macos_input.resolve_key_code("F12"), 111)
        self.assertEqual(macos_input.resolve_key_code("UnknownKey", 88), 88)
        self.assertEqual(macos_input.resolve_key_code("UnknownKey", None), 124)

    def test_trigger_page_turn_keyboard_and_click_mocked(self) -> None:
        fake_quartz = types.SimpleNamespace(
            kCGHIDEventTap=0,
            kCGEventMouseMoved=5,
            kCGEventLeftMouseDown=1,
            kCGEventLeftMouseUp=2,
            kCGMouseButtonLeft=0,
            CGPointMake=mock.MagicMock(side_effect=lambda x, y: (x, y)),
            CGEventCreateKeyboardEvent=mock.MagicMock(return_value=object()),
            CGEventCreateMouseEvent=mock.MagicMock(return_value=object()),
            CGEventPost=mock.MagicMock(),
        )

        with mock.patch.object(macos_input.sys, "platform", "darwin"), mock.patch.dict(
            sys.modules, {"Quartz": fake_quartz}
        ), mock.patch.object(macos_input.time, "sleep"):
            # Disabled page turn does nothing
            self.assertFalse(
                macos_input.trigger_page_turn({"enabled": False, "mode": "keyboard"})
            )

            # Keyboard mode
            ok_kb = macos_input.trigger_page_turn(
                {"enabled": True, "mode": "keyboard", "key_name": "Space"}
            )
            self.assertTrue(ok_kb)
            fake_quartz.CGEventCreateKeyboardEvent.assert_any_call(None, 49, True)
            fake_quartz.CGEventCreateKeyboardEvent.assert_any_call(None, 49, False)
            self.assertEqual(fake_quartz.CGEventPost.call_count, 2)

            # Click mode
            fake_quartz.CGEventPost.reset_mock()
            ok_click = macos_input.trigger_page_turn(
                {"enabled": True, "mode": "click", "click_x": 612, "click_y": 418}
            )
            self.assertTrue(ok_click)
            fake_quartz.CGPointMake.assert_called_with(612.0, 418.0)
            self.assertEqual(fake_quartz.CGEventCreateMouseEvent.call_count, 3)
            self.assertEqual(fake_quartz.CGEventPost.call_count, 3)

    def test_keyboard_osascript_fallback(self) -> None:
        broken_quartz = types.SimpleNamespace(
            kCGHIDEventTap=0,
            CGEventCreateKeyboardEvent=mock.MagicMock(
                side_effect=RuntimeError("Quartz unavailable")
            ),
            CGEventPost=mock.MagicMock(),
        )
        completed = subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
        with mock.patch.object(macos_input.sys, "platform", "darwin"), mock.patch.dict(
            sys.modules, {"Quartz": broken_quartz}
        ), mock.patch.object(
            macos_input.subprocess, "run", return_value=completed
        ) as run_mock:
            self.assertTrue(macos_input.send_keyboard_shortcut(121))
            run_mock.assert_called_once()
            cmd = run_mock.call_args[0][0]
            self.assertEqual(cmd[0], "osascript")
            self.assertIn("121", cmd[2])

    def test_target_pid_stage_manager_finder_filtering_and_quartz_shortcut(self) -> None:
        onscreen_windows = [
            {
                "kCGWindowLayer": 0,
                "kCGWindowOwnerPID": os.getpid(),
                "kCGWindowOwnerName": "Python",
                "kCGWindowBounds": {"X": 0, "Y": 0, "Width": 1200, "Height": 800},
            },
            {
                "kCGWindowLayer": 0,
                "kCGWindowOwnerPID": 608,
                "kCGWindowOwnerName": "Finder",
                "kCGWindowBounds": {"X": 150, "Y": 150, "Width": 820, "Height": 450},
            },
            {
                "kCGWindowLayer": 0,
                "kCGWindowOwnerPID": 43210,
                "kCGWindowOwnerName": "Safari",
                # Stage Manager strip thumbnail (too small to overlap full capture region)
                "kCGWindowBounds": {"X": 16, "Y": 599, "Width": 144, "Height": 132},
            },
        ]
        all_windows = onscreen_windows + [
            {
                "kCGWindowLayer": 0,
                "kCGWindowOwnerPID": 43210,
                "kCGWindowOwnerName": "Safari",
                # Full off-stage window in Stage Manager overlapping capture region
                "kCGWindowBounds": {"X": 300, "Y": 200, "Width": 900, "Height": 700},
            }
        ]

        def copy_win_info(opts, _win_id):
            if opts & 1:  # kCGWindowListOptionOnScreenOnly
                return onscreen_windows
            return all_windows

        fake_quartz = types.SimpleNamespace(
            kCGHIDEventTap=0,
            kCGWindowListOptionOnScreenOnly=1,
            kCGWindowListExcludeDesktopElements=16,
            kCGNullWindowID=0,
            CGWindowListCopyWindowInfo=mock.MagicMock(side_effect=copy_win_info),
            CGEventCreateKeyboardEvent=mock.MagicMock(return_value=object()),
            CGEventPost=mock.MagicMock(),
        )
        running_app_mock = mock.MagicMock()
        running_app_mock.activateWithOptions_.return_value = True
        front_app_mock = mock.MagicMock()
        # Even if NSWorkspace briefly thinks target is frontmost, Finder (608) is topmost full window
        front_app_mock.processIdentifier.return_value = 43210
        ws_mock = mock.MagicMock()
        ws_mock.frontmostApplication.return_value = front_app_mock
        fake_appkit = types.SimpleNamespace(
            NSWorkspace=types.SimpleNamespace(sharedWorkspace=mock.MagicMock(return_value=ws_mock)),
            NSRunningApplication=types.SimpleNamespace(
                runningApplicationWithProcessIdentifier_=mock.MagicMock(return_value=running_app_mock)
            ),
        )
        with mock.patch.object(macos_input.sys, "platform", "darwin"), mock.patch.dict(
            sys.modules, {"Quartz": fake_quartz, "AppKit": fake_appkit}
        ), mock.patch.object(
            macos_input.time, "sleep"
        ), mock.patch.object(
            macos_input.subprocess, "run"
        ) as run_mock:
            pid = macos_input.find_target_pid_for_region({"x": 320, "y": 220, "width": 600, "height": 400})
            # Must select Stage Manager Safari (43210) instead of Finder (608)
            self.assertEqual(pid, 43210)
            self.assertTrue(macos_input.send_keyboard_shortcut(125, target_pid=pid))
            running_app_mock.activateWithOptions_.assert_called_once_with(2)
            self.assertEqual(fake_quartz.CGEventPost.call_count, 2)
            # Quartz succeeded -> must NOT invoke slow osascript
            run_mock.assert_not_called()

            # When only Finder overlaps and no Stage Manager primary window exists, falls back to Finder
            all_windows[:] = onscreen_windows[:2]
            onscreen_windows[:] = onscreen_windows[:2]
            fallback_pid = macos_input.find_target_pid_for_region({"x": 320, "y": 220, "width": 600, "height": 400})
            self.assertEqual(fallback_pid, 608)


class TestMacOSCaptureAndSound(BaseIsolatedTestCase):
    """Verify HiDPI math, filename collision handling, sound, and CaptureController."""

    def test_read_png_dimensions_and_hidpi_conversions(self) -> None:
        png_path = self.tmp_path / "sample.png"
        png_path.write_bytes(_make_minimal_png(3024, 1964))
        self.assertEqual(macos_capture.read_png_dimensions(str(png_path)), (3024, 1964))

        bad_path = self.tmp_path / "bad.png"
        bad_path.write_bytes(b"not-a-png")
        with self.assertRaises(ValueError):
            macos_capture.read_png_dimensions(str(bad_path))

        rect = macos_capture.convert_canvas_rect_to_logical(
            px_x=200, px_y=400, px_w=1600, px_h=1200, scale_factor=2.0, origin_x=10, origin_y=20
        )
        self.assertEqual(rect, {"x": 110, "y": 220, "width": 800, "height": 600})

        tiny_rect = macos_capture.convert_canvas_rect_to_logical(
            px_x=0, px_y=0, px_w=4, px_h=4, scale_factor=2.0
        )
        self.assertEqual(tiny_rect["width"], 10)
        self.assertEqual(tiny_rect["height"], 10)

        pt = macos_capture.convert_canvas_point_to_logical(
            px_x=1000, px_y=800, scale_factor=2.0, origin_x=-1440, origin_y=0
        )
        self.assertEqual(pt, {"click_x": -940, "click_y": 400})

    def test_generate_screenshot_filename_preserves_scan_and_sort_compatibility(self) -> None:
        shots_dir = self.tmp_path / "gen_shots"
        shots_dir.mkdir()
        fixed_dt = datetime(2026, 11, 14, 23, 59, 58)

        first = macos_capture.generate_screenshot_filename(str(shots_dir), now=fixed_dt)
        self.assertEqual(first, "Screenshot 2026-11-14 at 23.59.58.png")
        self.assertTrue(app_module.is_screenshot_file(first))
        self.assertEqual(app_module.get_sort_key(first), 23 * 3600 + 59 * 60 + 58)
        (shots_dir / first).write_bytes(b"1")

        second = macos_capture.generate_screenshot_filename(str(shots_dir), now=fixed_dt)
        self.assertEqual(second, "Screenshot 2026-11-14 at 23.59.59.png")
        self.assertTrue(app_module.is_screenshot_file(second))
        self.assertGreater(app_module.get_sort_key(second), app_module.get_sort_key(first))
        (shots_dir / second).write_bytes(b"2")

        # Day boundary after 23:59:59 falls back to "(2) at HH.MM.SS.png"
        third = macos_capture.generate_screenshot_filename(str(shots_dir), now=fixed_dt)
        self.assertEqual(third, "Screenshot 2026-11-14 (2) at 23.59.58.png")
        self.assertTrue(app_module.is_screenshot_file(third))
        self.assertGreater(app_module.get_sort_key(third), 0)

    def test_play_shutter_sound_non_blocking(self) -> None:
        with mock.patch.object(macos_sound.sys, "platform", "darwin"), mock.patch.object(
            macos_sound.os.path, "exists", return_value=True
        ), mock.patch.object(macos_sound.subprocess, "Popen") as popen_mock:
            self.assertFalse(macos_sound.play_shutter_sound(enabled=False))
            popen_mock.assert_not_called()

            self.assertTrue(macos_sound.play_shutter_sound(enabled=True))
            popen_mock.assert_called_once()
            args, kwargs = popen_mock.call_args
            self.assertEqual(args[0], ["afplay", macos_sound.MACOS_CAPTURE_SOUND])
            self.assertTrue(kwargs.get("start_new_session"))

    def test_capture_controller_max_shots_no_extra_turn_and_sound(self) -> None:
        shots_dir = self.tmp_path / "loop_shots"
        controller = macos_capture.CaptureController()
        callbacks: list[tuple[str, str]] = []

        def fake_screencapture(cmd, capture_output=True, text=True, timeout=15):
            out_path = cmd[-1]
            pathlib.Path(out_path).write_bytes(_make_minimal_png(800, 600))
            return subprocess.CompletedProcess(cmd, 0, "", "")

        # Verify clamping of invalid interval (0 -> 1) and wait timeout usage
        with mock.patch.object(macos_capture.sys, "platform", "darwin"), mock.patch.object(
            macos_capture.subprocess, "run", side_effect=fake_screencapture
        ), mock.patch.object(
            macos_capture, "play_shutter_sound", return_value=True
        ) as sound_mock, mock.patch.object(
            macos_capture, "find_target_pid_for_region", return_value=None
        ), mock.patch.object(
            macos_capture, "trigger_page_turn", return_value=True
        ) as turn_mock:
            # Speed up threading.Event.wait only for 1s interval sleeps? Better: pass interval=1,
            # mock Event.wait? No, let's test real Event.wait with a short mock on wait timeout or real 1s!
            # Patching capture_region_once / wait is risky; with max_shots=2 and countdown_sec=0,
            # 1s interval takes ~1.0s real time and tests genuine threading.Event behavior.
            res = controller.start(
                {
                    "save_folder": str(shots_dir),
                    "region": {"x": 10, "y": 20, "width": 800, "height": 600},
                    "interval_sec": 0,  # clamps to 1
                    "countdown_sec": 0,
                    "max_shots": 2,
                    "sound_enabled": True,
                    "page_turn": {"enabled": True, "mode": "keyboard", "key_name": "ArrowRight"},
                },
                on_shot_callback=lambda folder, fname: callbacks.append((folder, fname)),
            )
            self.assertTrue(res["ok"])
            self.assertEqual(res["status"]["interval_sec"], 1)

            deadline = time.monotonic() + 5.0
            while time.monotonic() < deadline:
                st = controller.get_status()
                if not st["running"]:
                    break
                time.sleep(0.05)

            final_status = controller.get_status()
            self.assertFalse(final_status["running"])
            self.assertEqual(final_status["phase"], "completed")
            self.assertEqual(final_status["captured_count"], 2)
            self.assertEqual(len(final_status["captured_files"]), 2)
            self.assertEqual(len(callbacks), 2)
            self.assertEqual(sound_mock.call_count, 2)
            # Crucial invariant: 2 shots => page turn called ONLY once (not after final shot)
            self.assertEqual(turn_mock.call_count, 1)

    def test_capture_controller_reports_blocked_page_turn_error(self) -> None:
        shots_dir = self.tmp_path / "blocked_turn_shots"
        controller = macos_capture.CaptureController()

        def fake_screencapture(cmd, capture_output=True, text=True, timeout=15):
            pathlib.Path(cmd[-1]).write_bytes(_make_minimal_png(400, 300))
            return subprocess.CompletedProcess(cmd, 0, "", "")

        with mock.patch.object(macos_capture.sys, "platform", "darwin"), mock.patch.object(
            macos_capture.subprocess, "run", side_effect=fake_screencapture
        ), mock.patch.object(
            macos_capture, "play_shutter_sound", return_value=True
        ), mock.patch.object(
            macos_capture, "find_target_pid_for_region", return_value=None
        ), mock.patch.object(
            macos_capture, "trigger_page_turn", return_value=False
        ):
            res = controller.start(
                {
                    "save_folder": str(shots_dir),
                    "region": {"x": 0, "y": 0, "width": 400, "height": 300},
                    "interval_sec": 1,
                    "countdown_sec": 0,
                    "max_shots": 2,
                    "sound_enabled": False,
                    "page_turn": {"enabled": True, "mode": "keyboard", "key_name": "ArrowDown"},
                }
            )
            self.assertTrue(res["ok"])
            deadline = time.monotonic() + 5.0
            while time.monotonic() < deadline:
                st = controller.get_status()
                if not st["running"]:
                    break
                time.sleep(0.05)

            final_status = controller.get_status()
            self.assertEqual(final_status["phase"], "completed")
            self.assertIn("Accessibility", final_status["last_error"] or "")

    def test_capture_controller_immediate_stop_abort(self) -> None:
        shots_dir = self.tmp_path / "abort_shots"
        controller = macos_capture.CaptureController()
        shot_taken = threading.Event()

        def fake_screencapture(cmd, capture_output=True, text=True, timeout=15):
            pathlib.Path(cmd[-1]).write_bytes(_make_minimal_png(400, 300))
            shot_taken.set()
            return subprocess.CompletedProcess(cmd, 0, "", "")

        with mock.patch.object(macos_capture.sys, "platform", "darwin"), mock.patch.object(
            macos_capture.subprocess, "run", side_effect=fake_screencapture
        ), mock.patch.object(
            macos_capture, "play_shutter_sound", return_value=True
        ), mock.patch.object(
            macos_capture, "find_target_pid_for_region", return_value=None
        ), mock.patch.object(
            macos_capture, "trigger_page_turn", return_value=True
        ):
            res = controller.start(
                {
                    "save_folder": str(shots_dir),
                    "region": {"x": 0, "y": 0, "width": 400, "height": 300},
                    "interval_sec": 10,  # Long 10s wait that must abort immediately on stop()
                    "countdown_sec": 0,
                    "max_shots": 0,
                    "sound_enabled": False,
                    "page_turn": {"enabled": True, "mode": "keyboard"},
                }
            )
            self.assertTrue(res["ok"])
            self.assertTrue(shot_taken.wait(timeout=2.0))
            time.sleep(0.05)

            t0 = time.monotonic()
            stopped_status = controller.stop()
            elapsed = time.monotonic() - t0

            self.assertLess(elapsed, 1.0)
            self.assertFalse(stopped_status["running"])
            self.assertEqual(stopped_status["phase"], "stopped")
            self.assertEqual(stopped_status["captured_count"], 1)

    def test_capture_controller_countdown_phase_and_abort(self) -> None:
        shots_dir = self.tmp_path / "countdown_shots"
        controller = macos_capture.CaptureController()
        fake_png = _make_minimal_png(400, 300)

        def fake_screencapture(cmd, capture_output=True, text=True, timeout=15):
            pathlib.Path(cmd[-1]).write_bytes(fake_png)
            return subprocess.CompletedProcess(cmd, 0, "", "")

        with mock.patch.object(macos_capture.sys, "platform", "darwin"), mock.patch.object(
            macos_capture.subprocess, "run", side_effect=fake_screencapture
        ), mock.patch.object(
            macos_capture, "play_shutter_sound", return_value=True
        ), mock.patch.object(
            macos_capture, "trigger_page_turn", return_value=True
        ):
            res = controller.start(
                {
                    "save_folder": str(shots_dir),
                    "region": {"x": 0, "y": 0, "width": 400, "height": 300},
                    "interval_sec": 1,
                    "countdown_sec": 5,
                    "max_shots": 1,
                    "sound_enabled": False,
                    "page_turn": {"enabled": False},
                }
            )
            self.assertTrue(res["ok"])
            self.assertEqual(res["status"]["phase"], "countdown")
            self.assertEqual(res["status"]["countdown_remaining"], 5)

            t0 = time.monotonic()
            stopped = controller.stop()
            elapsed = time.monotonic() - t0
            self.assertLess(elapsed, 1.0)
            self.assertEqual(stopped["phase"], "stopped")
            self.assertFalse(stopped["running"])
            self.assertEqual(stopped["captured_count"], 0)

    def test_capture_fullscreen_preview_and_region_once_mocked(self) -> None:
        preview_file = pathlib.Path(tempfile.gettempdir()) / "screenshot_indexing_preview.png"
        backup_bytes = preview_file.read_bytes() if preview_file.exists() else None
        try:
            def fake_run(cmd, capture_output=True, text=True, timeout=15):
                out_path = cmd[-1]
                if "-R" in cmd:
                    pathlib.Path(out_path).write_bytes(_make_minimal_png(600, 400))
                else:
                    pathlib.Path(out_path).write_bytes(_make_minimal_png(3024, 1964))
                return subprocess.CompletedProcess(cmd, 0, "", "")

            with mock.patch.object(macos_capture.sys, "platform", "darwin"), mock.patch.object(
                macos_capture.subprocess, "run", side_effect=fake_run
            ) as run_mock, mock.patch.object(
                macos_capture,
                "get_main_display_info",
                return_value={
                    "origin_x": 0,
                    "origin_y": 0,
                    "screen_width": 1512,
                    "screen_height": 982,
                },
            ), mock.patch.object(
                macos_capture, "play_shutter_sound", return_value=True
            ) as sound_mock:
                prev = macos_capture.capture_fullscreen_preview(delay_sec=0.0)
                self.assertTrue(prev["ok"])
                self.assertEqual(prev["scale_factor"], 2.0)
                self.assertEqual(prev["image_width"], 3024)
                self.assertEqual(run_mock.call_args_list[0][0][0][:2], ["screencapture", "-x"])

                shots_dir = self.tmp_path / "single_shot"
                shot = macos_capture.capture_region_once(
                    str(shots_dir),
                    {"x": 15, "y": 25, "width": 300, "height": 200},
                    sound_enabled=True,
                )
                self.assertTrue(shot["ok"])
                self.assertTrue(pathlib.Path(shot["path"]).is_file())
                cmd_shot = run_mock.call_args_list[1][0][0]
                self.assertEqual(cmd_shot[:4], ["screencapture", "-x", "-R", "15,25,300,200"])
                sound_mock.assert_called_once_with(True)
        finally:
            if backup_bytes is not None:
                preview_file.write_bytes(backup_bytes)
            elif preview_file.exists():
                preview_file.unlink()

    def test_capture_quartz_fallback_and_controller_reset(self) -> None:
        preview_file = pathlib.Path(tempfile.gettempdir()) / "screenshot_indexing_preview.png"
        backup_bytes = preview_file.read_bytes() if preview_file.exists() else None
        try:
            def failed_screencapture(cmd, capture_output=True, text=True, timeout=15):
                return subprocess.CompletedProcess(
                    cmd, 1, "", "could not create image from rect"
                )

            def fake_quartz_capture(output_path, region=None):
                dims = (600, 400) if region else (3024, 1964)
                pathlib.Path(output_path).write_bytes(_make_minimal_png(*dims))
                return True

            with mock.patch.object(macos_capture.sys, "platform", "darwin"), mock.patch.object(
                macos_capture.subprocess, "run", side_effect=failed_screencapture
            ), mock.patch.object(
                macos_capture, "_capture_with_quartz", side_effect=fake_quartz_capture
            ) as quartz_mock, mock.patch.object(
                macos_capture,
                "get_main_display_info",
                return_value={
                    "origin_x": 0,
                    "origin_y": 0,
                    "screen_width": 1512,
                    "screen_height": 982,
                },
            ), mock.patch.object(
                macos_capture, "play_shutter_sound", return_value=True
            ) as sound_mock:
                prev = macos_capture.capture_fullscreen_preview(delay_sec=0.0)
                self.assertTrue(prev["ok"])
                self.assertEqual(prev["image_width"], 3024)

                shots_dir = self.tmp_path / "quartz_fallback_shots"
                shot = macos_capture.capture_region_once(
                    str(shots_dir),
                    {"x": 100, "y": 100, "width": 300, "height": 200},
                    sound_enabled=True,
                )
                self.assertTrue(shot["ok"])
                self.assertTrue(pathlib.Path(shot["path"]).is_file())
                self.assertEqual(quartz_mock.call_count, 2)
                sound_mock.assert_called_once_with(True)

            controller = macos_capture.CaptureController()
            with controller._lock:
                controller._phase = "error"
                controller._captured_count = 7
                controller._save_folder = "/tmp/old"
                controller._last_file = "old.png"
                controller._captured_files = ["old.png"]
                controller._last_error = "old err"

            reset_status = controller.reset()
            self.assertFalse(reset_status["running"])
            self.assertEqual(reset_status["phase"], "idle")
            self.assertEqual(reset_status["captured_count"], 0)
            self.assertEqual(reset_status["save_folder"], "")
            self.assertIsNone(reset_status["last_file"])
            self.assertEqual(reset_status["captured_files"], [])
            self.assertIsNone(reset_status["last_error"])
        finally:
            if backup_bytes is not None:
                preview_file.write_bytes(backup_bytes)
            elif preview_file.exists():
                preview_file.unlink()

    def test_overlay_subprocess_and_permissions_mocked(self) -> None:
        region_proc = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout=json.dumps(
                {
                    "ok": True,
                    "cancelled": False,
                    "region": {"x": 20, "y": 40, "width": 500, "height": 400},
                }
            )
            + "\n",
            stderr="",
        )
        with mock.patch.object(macos_overlay.sys, "platform", "darwin"), mock.patch.object(
            macos_overlay.subprocess, "run", return_value=region_proc
        ) as run_mock:
            with mock.patch.object(macos_overlay.sys, "frozen", False, create=True):
                res_dev = macos_overlay.pick_screen_overlay("region")
                self.assertTrue(res_dev["ok"])
                self.assertEqual(run_mock.call_args[0][0][1:5], ["-m", "services.macos_overlay", "--target", "region"])

            with mock.patch.object(macos_overlay.sys, "frozen", True, create=True):
                res_frozen = macos_overlay.pick_screen_overlay("click")
                self.assertTrue(res_frozen["ok"])
                self.assertEqual(run_mock.call_args[0][0][1:], ["--overlay-picker", "click"])

        fake_quartz = types.SimpleNamespace(
            CGPreflightScreenCaptureAccess=mock.MagicMock(return_value=False),
            CGRequestScreenCaptureAccess=mock.MagicMock(return_value=True),
        )
        fake_ax = mock.MagicMock(return_value=True)
        fake_framework = types.SimpleNamespace(AXIsProcessTrusted=fake_ax)
        with mock.patch.object(macos_permissions.sys, "platform", "darwin"), mock.patch.dict(
            sys.modules, {"Quartz": fake_quartz}
        ), mock.patch.object(
            macos_permissions.ctypes, "CDLL", return_value=fake_framework
        ):
            perms = macos_permissions.check_permissions(prompt=True)
            self.assertEqual(perms, {"screen_recording": True, "accessibility": True})
            fake_quartz.CGRequestScreenCaptureAccess.assert_called_once()


class TestNewFlaskCaptureEndpoints(BaseIsolatedTestCase):
    """Verify all new /api/settings and /api/capture/* endpoints including EN/VI & traversal safety."""

    def test_settings_get_and_post(self) -> None:
        with mock.patch.object(
            app_module,
            "check_permissions",
            return_value={"screen_recording": True, "accessibility": False},
        ):
            get_res = self.client.get("/api/settings").get_json()
            self.assertTrue(get_res["ok"])
            self.assertEqual(get_res["permissions"], {"screen_recording": True, "accessibility": False})
            self.assertEqual(get_res["settings"]["interval_sec"], 3)

        target_dir = self.tmp_path / "captured_pages"
        post_res = self.client.post(
            "/api/settings",
            json={
                "save_folder": str(target_dir),
                "interval_sec": 15,
                "region": {"x": 12, "y": 34, "width": 500, "height": 400},
                "page_turn": {"mode": "keyboard", "key_name": "PageDown"},
                "lang": "vi",
            },
        ).get_json()
        self.assertTrue(post_res["ok"])
        self.assertTrue(target_dir.is_dir())
        self.assertEqual(post_res["settings"]["interval_sec"], 10)
        self.assertEqual(post_res["settings"]["page_turn"]["key_code"], 121)
        self.assertEqual(post_res["message"], "Đã lưu cài đặt thành công")
        self.assertEqual(app_module.state["folder_path"], str(target_dir))

    def test_permissions_endpoint(self) -> None:
        with mock.patch.object(
            app_module,
            "check_permissions",
            return_value={"screen_recording": True, "accessibility": True},
        ) as perm_mock:
            res = self.client.post(
                "/api/capture/permissions", json={"prompt": True, "lang": "en"}
            ).get_json()
            perm_mock.assert_called_once_with(prompt=True)
            self.assertTrue(res["ok"])
            self.assertTrue(res["permissions"]["screen_recording"])

    def test_preview_screen_and_preview_image(self) -> None:
        preview_file = pathlib.Path(tempfile.gettempdir()) / "screenshot_indexing_preview.png"
        backup_bytes = preview_file.read_bytes() if preview_file.exists() else None
        try:
            if preview_file.exists():
                preview_file.unlink()

            missing_resp = self.client.get("/api/capture/preview-image?lang=vi")
            self.assertEqual(missing_resp.status_code, 404)
            self.assertIn("Không tìm thấy", missing_resp.get_data(as_text=True))

            preview_file.write_bytes(_make_minimal_png(3024, 1964))
            with mock.patch.object(
                app_module,
                "capture_fullscreen_preview",
                return_value={
                    "ok": True,
                    "preview_path": str(preview_file),
                    "screen_width": 1512,
                    "screen_height": 982,
                    "image_width": 3024,
                    "image_height": 1964,
                    "scale_factor": 2.0,
                    "origin_x": 0,
                    "origin_y": 0,
                },
            ):
                res = self.client.post(
                    "/api/capture/preview-screen", json={"delay_sec": 0.2, "lang": "en"}
                ).get_json()
                self.assertTrue(res["ok"])
                self.assertEqual(res["scale_factor"], 2.0)
                self.assertTrue(res["image_url"].startswith("/api/capture/preview-image?t="))

            img_resp = self.client.get("/api/capture/preview-image")
            self.assertEqual(img_resp.status_code, 200)
            self.assertTrue(img_resp.get_data().startswith(b"\x89PNG"))
            img_resp.close()

            with mock.patch.object(
                app_module,
                "capture_fullscreen_preview",
                return_value={"ok": False, "error": "TCC denied"},
            ), mock.patch.object(
                app_module,
                "check_permissions",
                return_value={"screen_recording": False, "accessibility": False},
            ):
                fail_vi = self.client.post(
                    "/api/capture/preview-screen", json={"delay_sec": 0.2, "lang": "vi"}
                ).get_json()
                self.assertFalse(fail_vi["ok"])
                self.assertIn("Ghi màn hình", fail_vi["message"])
        finally:
            if backup_bytes is not None:
                preview_file.write_bytes(backup_bytes)
            elif preview_file.exists():
                preview_file.unlink()

    def test_pick_overlay_endpoint_region_click_and_cancel(self) -> None:
        with mock.patch.object(
            app_module,
            "pick_screen_overlay",
            return_value={
                "ok": True,
                "cancelled": False,
                "region": {"x": 50, "y": 60, "width": 700, "height": 500},
            },
        ):
            res = self.client.post(
                "/api/capture/pick-overlay", json={"target": "region", "lang": "en"}
            ).get_json()
            self.assertTrue(res["ok"])
            self.assertEqual(res["region"], {"x": 50, "y": 60, "width": 700, "height": 500})

        with mock.patch.object(
            app_module,
            "pick_screen_overlay",
            return_value={
                "ok": True,
                "cancelled": False,
                "click_point": {"click_x": 910, "click_y": 540},
            },
        ):
            res = self.client.post(
                "/api/capture/pick-overlay", json={"target": "click", "lang": "en"}
            ).get_json()
            self.assertTrue(res["ok"])
            self.assertEqual(res["click_point"], {"click_x": 910, "click_y": 540})

        with mock.patch.object(
            app_module,
            "pick_screen_overlay",
            return_value={"ok": False, "cancelled": True, "message": "Cancelled"},
        ):
            res_vi = self.client.post(
                "/api/capture/pick-overlay", json={"target": "region", "lang": "vi"}
            ).get_json()
            self.assertFalse(res_vi["ok"])
            self.assertTrue(res_vi["cancelled"])
            self.assertEqual(res_vi["message"], "Đã hủy chọn trên màn hình")

    def test_capture_start_stop_status_and_validation(self) -> None:
        # Missing save_folder
        err_folder = self.client.post(
            "/api/capture/start", json={"save_folder": "", "lang": "en"}
        ).get_json()
        self.assertFalse(err_folder["ok"])
        self.assertEqual(err_folder["message"], "Please select a save folder for screenshots")

        # Invalid region < 10
        out_dir = self.tmp_path / "cap_out"
        err_region = self.client.post(
            "/api/capture/start",
            json={
                "save_folder": str(out_dir),
                "region": {"x": 0, "y": 0, "width": 5, "height": 100},
                "lang": "vi",
            },
        ).get_json()
        self.assertFalse(err_region["ok"])
        self.assertIn("tối thiểu 10", err_region["message"])

        fake_running = {
            "running": True,
            "phase": "countdown",
            "countdown_remaining": 3,
            "captured_count": 0,
            "max_shots": 5,
            "interval_sec": 3,
            "save_folder": str(out_dir),
            "last_file": None,
            "captured_files": [],
            "last_error": None,
        }
        fake_stopped = {**fake_running, "running": False, "phase": "stopped"}

        with mock.patch.object(
            app_module.capture_controller, "get_status", return_value={"running": False, "phase": "idle"}
        ), mock.patch.object(
            app_module.capture_controller,
            "start",
            return_value={"ok": True, "status": fake_running},
        ) as start_mock:
            start_res = self.client.post(
                "/api/capture/start",
                json={
                    "save_folder": str(out_dir),
                    "region": {"x": 10, "y": 20, "width": 800, "height": 600},
                    "interval_sec": 4,
                    "lang": "en",
                },
            ).get_json()
            self.assertTrue(start_res["ok"])
            self.assertEqual(start_res["status"]["phase"], "countdown")
            self.assertEqual(start_res["message"], "Auto capture started")
            start_mock.assert_called_once()

        with mock.patch.object(
            app_module.capture_controller, "get_status", return_value=fake_running
        ):
            status_res = self.client.get("/api/capture/status").get_json()
            self.assertTrue(status_res["ok"])
            self.assertTrue(status_res["status"]["running"])

            dup_res = self.client.post(
                "/api/capture/start", json={"save_folder": str(out_dir), "lang": "vi"}
            ).get_json()
            self.assertFalse(dup_res["ok"])
            self.assertEqual(dup_res["message"], "Tiến trình tự động chụp đang chạy")

        with mock.patch.object(
            app_module.capture_controller, "stop", return_value=fake_stopped
        ):
            stop_res = self.client.post("/api/capture/stop", json={"lang": "vi"}).get_json()
            self.assertTrue(stop_res["ok"])
            self.assertFalse(stop_res["status"]["running"])
            self.assertEqual(stop_res["message"], "Đã dừng tự động chụp màn hình")

    def test_latest_image_endpoint_and_path_traversal_guard(self) -> None:
        shots_dir = self.tmp_path / "latest_dir"
        shots_dir.mkdir()
        valid_name = "Screenshot 2026-11-14 at 12.00.00.png"
        (shots_dir / valid_name).write_bytes(_make_minimal_png(200, 150))
        config_store.save_config({"save_folder": str(shots_dir)})

        ok_resp = self.client.get(f"/api/capture/latest-image?name={valid_name}")
        self.assertEqual(ok_resp.status_code, 200)
        self.assertTrue(ok_resp.get_data().startswith(b"\x89PNG"))
        ok_resp.close()

        for bad_name in ("", "..", ".", "../secret.png", "sub/file.png", "sub\\file.png", "missing.png"):
            bad_resp = self.client.get(
                f"/api/capture/latest-image?name={bad_name}&lang=en"
            )
            self.assertEqual(bad_resp.status_code, 404, f"Expected 404 for {bad_name!r}")

    def test_cleanup_session_resets_state_config_and_preview(self) -> None:
        preview_file = pathlib.Path(tempfile.gettempdir()) / "screenshot_indexing_preview.png"
        backup_bytes = preview_file.read_bytes() if preview_file.exists() else None
        try:
            shots_dir = self.tmp_path / "session_shots"
            shots_dir.mkdir()
            config_store.save_config({"save_folder": str(shots_dir), "max_shots": 12})
            app_module.state["folder_path"] = str(shots_dir)
            app_module.state["files"] = ["Screenshot 2026-11-14 at 10.00.01.png"]
            preview_file.write_bytes(_make_minimal_png(200, 150))

            app_module.cleanup_session()

            self.assertFalse(self.config_path.exists())
            self.assertFalse(preview_file.exists())
            self.assertEqual(app_module.state["folder_path"], "")
            self.assertEqual(app_module.state["files"], [])
            self.assertEqual(app_module.capture_controller.get_status()["phase"], "idle")
        finally:
            if backup_bytes is not None:
                preview_file.write_bytes(backup_bytes)
            elif preview_file.exists():
                preview_file.unlink()


class TestI18nAndPackagingIntegrity(unittest.TestCase):
    """Verify EN/VI parity across HTML/JS/Python, JS syntax, and Apple Silicon CI packaging."""

    def test_en_vi_i18n_parity(self) -> None:
        html = (PROJECT_ROOT / "templates" / "index.html").read_text(encoding="utf-8")
        js = (PROJECT_ROOT / "static" / "app.js").read_text(encoding="utf-8")
        py = (PROJECT_ROOT / "app.py").read_text(encoding="utf-8")

        html_keys = set(
            re.findall(r'data-i18n(?:-(?:placeholder|title))?="([^"]+)"', html)
        )
        js_t_keys = set(re.findall(r"\bt\(\s*'([^']+)'", js))

        en_match = re.search(r"en:\s*\{(.*?)\n\s*\},\s*\n\s*vi:", js, re.S)
        vi_match = re.search(r"vi:\s*\{(.*?)\n\s*\}\s*\n\};", js, re.S)
        self.assertIsNotNone(en_match, "Could not parse translations.en in static/app.js")
        self.assertIsNotNone(vi_match, "Could not parse translations.vi in static/app.js")

        en_keys = set(re.findall(r"^\s*([a-zA-Z0-9_]+):", en_match.group(1), re.M))
        vi_keys = set(re.findall(r"^\s*([a-zA-Z0-9_]+):", vi_match.group(1), re.M))

        self.assertEqual(sorted((html_keys | js_t_keys) - en_keys), [])
        self.assertEqual(sorted((html_keys | js_t_keys) - vi_keys), [])
        self.assertEqual(sorted(en_keys ^ vi_keys), [])
        self.assertNotIn("${t('btn_renaming')}", vi_match.group(1))

        msgs_match = re.search(r"msgs\s*=\s*\{(.*?)\n\s*\}", py, re.S)
        self.assertIsNotNone(msgs_match, "Could not parse msgs dict in app.py")
        py_keys = set(re.findall(r'"([^"]+)":\s*\{', msgs_match.group(1)))
        py_used = set(re.findall(r"get_msg\(\s*['\"]([^'\"]+)['\"]", py))
        self.assertEqual(sorted(py_used - py_keys), [])

        for key in py_keys:
            self.assertTrue(app_module.get_msg(key, "en"), f"Missing EN for {key}")
            self.assertTrue(app_module.get_msg(key, "vi"), f"Missing VI for {key}")

        # Verify DOM IDs & inline event handlers match between HTML & JS
        html_ids = set(re.findall(r'\bid="([^"]+)"', html))
        js_ids = set(
            re.findall(
                r"(?:\$|document\.getElementById)\(\s*['\"]#?([a-zA-Z0-9_-]+)['\"]\s*\)",
                js,
            )
        )
        self.assertEqual(sorted((js_ids - html_ids) - {"status-text", "status-dot"}), [])

        js_funcs = set(re.findall(r"(?:async\s+)?function\s+([a-zA-Z0-9_]+)\s*\(", js))
        for attr_val in re.findall(r'\bon(?:click|change|input|keydown)="([^"]+)"', html):
            for fn in re.findall(r'\b([a-zA-Z_][a-zA-Z0-9_]*)\s*\(', attr_val):
                if fn not in ("if", "preventDefault"):
                    self.assertIn(fn, js_funcs, f"Undefined HTML handler {fn}()")

    def test_js_syntax_if_node_available(self) -> None:
        node_bin = shutil.which("node")
        if node_bin:
            proc = subprocess.run(
                [node_bin, "--check", str(PROJECT_ROOT / "static" / "app.js")],
                capture_output=True,
                text=True,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_arm64_workflow_and_merge_universal_removed(self) -> None:
        workflow_path = PROJECT_ROOT / ".github" / "workflows" / "build-and-release.yml"
        self.assertTrue(workflow_path.is_file())
        self.assertFalse(
            (PROJECT_ROOT / ".github" / "scripts" / "merge_universal.py").exists()
        )

        wf_text = workflow_path.read_text(encoding="utf-8")
        self.assertIn("Build macOS Apple Silicon (arm64)", wf_text)
        self.assertIn("--target-arch arm64", wf_text)
        self.assertIn('--add-data "templates:templates"', wf_text)
        self.assertIn('--add-data "static:static"', wf_text)
        self.assertIn('--add-data "services:services"', wf_text)
        self.assertIn("--hidden-import Quartz", wf_text)
        self.assertIn("--hidden-import AppKit", wf_text)
        self.assertIn("NSScreenCaptureUsageDescription", wf_text)
        self.assertIn("NSAppleEventsUsageDescription", wf_text)
        self.assertIn("Screenshot-Indexing-${VERSION}-macOS-arm64.dmg", wf_text)
        self.assertIn("-macOS-arm64", wf_text)
        self.assertNotIn("Build x86_64 App", wf_text)
        self.assertNotIn("merge_universal.py", wf_text)
        self.assertNotIn("--target-arch x86_64", wf_text)

        # Ensure Info.plist TCC keys are updated BEFORE xattr -cr and codesign
        idx_screen = wf_text.index("NSScreenCaptureUsageDescription")
        idx_apple = wf_text.index("NSAppleEventsUsageDescription")
        idx_xattr = wf_text.index('xattr -cr "dist/Screenshot Indexing.app"')
        idx_sign = wf_text.index('codesign --force --deep --sign - "dist/Screenshot Indexing.app"')
        self.assertLess(idx_screen, idx_xattr)
        self.assertLess(idx_apple, idx_xattr)
        self.assertLess(idx_xattr, idx_sign)

        ruby_bin = shutil.which("ruby")
        if ruby_bin:
            proc = subprocess.run(
                [ruby_bin, "-ryaml", "-e", f"YAML.load_file('{workflow_path}')"],
                capture_output=True,
                text=True,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)


if __name__ == "__main__":
    unittest.main()
