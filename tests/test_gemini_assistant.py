"""Unit tests for Gemini API assistant service, Flask AI routes, and EN/VI i18n parity."""

import json
import os
import re
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import app as app_module  # noqa: E402
from services import config_store  # noqa: E402
from services.gemini_assistant import (  # noqa: E402
    DEFAULT_GEMINI_MODEL,
    GeminiAssistantError,
    mask_api_key,
    resolve_api_key,
    sanitize_slug,
    suggest_filenames,
    summarize_screenshots,
)

# Minimal valid 1x1 transparent PNG bytes
TINY_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\rIDATx\x9cc`\x00\x00\x00"
    b"\x02\x00\x01H\xaf\xa4q\x00\x00\x00\x00IEND\xaeB`\x82"
)


class TestGeminiAssistantService(unittest.TestCase):
    def test_sanitize_slug_and_mask(self):
        self.assertEqual(sanitize_slug("Chapter 1: Intro!"), "chapter_1_intro")
        self.assertEqual(sanitize_slug("my_slide.png"), "my_slide")
        self.assertEqual(sanitize_slug("   "), "screenshot")
        self.assertEqual(mask_api_key(""), "")
        self.assertEqual(mask_api_key("short"), "••••")
        self.assertEqual(mask_api_key("AIzaSyTestKey1234"), "••••1234")

    def test_resolve_api_key_priority(self):
        with patch.dict(os.environ, {"GEMINI_API_KEY": "env-key-9999"}, clear=False):
            self.assertEqual(resolve_api_key("cfg-key-1234"), ("cfg-key-1234", "config"))
            self.assertEqual(resolve_api_key(""), ("env-key-9999", "env"))
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(resolve_api_key(""), ("", "none"))

    def test_suggest_filenames_uses_interactions_api_and_sanitizes(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            f1 = "Screenshot 2026-01-01 at 10.00.01.png"
            f2 = "Screenshot 2026-01-01 at 10.00.02.png"
            for name in (f1, f2):
                with open(os.path.join(tmpdir, name), "wb") as fp:
                    fp.write(TINY_PNG)

            mock_client = MagicMock()
            mock_client.interactions.create.return_value = SimpleNamespace(
                output_text=json.dumps({
                    "suggestions": [
                        {"original_name": f1, "slug": "System Overview!"},
                        {"original_name": f2, "slug": "System Overview!"},
                    ]
                })
            )

            with patch("services.gemini_assistant.genai.Client", return_value=mock_client) as client_cls:
                results = suggest_filenames(
                    folder=tmpdir,
                    filenames=[f1, f2],
                    start_num=1,
                    lang="en",
                    api_key="test-key",
                )

            client_cls.assert_called_once_with(api_key="test-key")
            call_kwargs = mock_client.interactions.create.call_args.kwargs
            self.assertEqual(call_kwargs["model"], DEFAULT_GEMINI_MODEL)
            self.assertEqual(call_kwargs["response_format"]["mime_type"], "application/json")
            image_blocks = [p for p in call_kwargs["input"] if p.get("type") == "image"]
            self.assertEqual(len(image_blocks), 2)
            self.assertEqual(image_blocks[0]["mime_type"], "image/png")

            self.assertEqual(len(results), 2)
            self.assertEqual(results[0]["new_name"], "01_system_overview.png")
            self.assertEqual(results[1]["new_name"], "02_system_overview.png")

    def test_summarize_screenshots_returns_markdown(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            f1 = "Screenshot 2026-01-01 at 10.00.01.png"
            with open(os.path.join(tmpdir, f1), "wb") as fp:
                fp.write(TINY_PNG)

            mock_client = MagicMock()
            mock_client.interactions.create.return_value = SimpleNamespace(
                output_text="## Page 1\n- Key takeaway"
            )

            with patch("services.gemini_assistant.genai.Client", return_value=mock_client):
                summary, count = summarize_screenshots(
                    folder=tmpdir,
                    filenames=[f1],
                    lang="en",
                    api_key="test-key",
                )

            self.assertEqual(count, 1)
            self.assertIn("Key takeaway", summary)


class TestFlaskGeminiEndpoints(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.cfg_path = os.path.join(self.tmpdir.name, "config.json")
        self.env_patch = patch.dict(
            os.environ,
            {"SCREENSHOT_INDEXING_CONFIG_PATH": self.cfg_path},
            clear=False,
        )
        self.env_patch.start()
        os.environ.pop("GEMINI_API_KEY", None)
        config_store.reset_config()
        app_module.state["folder_path"] = ""
        app_module.state["files"] = []
        self.client = app_module.app.test_client()

    def tearDown(self):
        app_module.state["folder_path"] = ""
        app_module.state["files"] = []
        self.env_patch.stop()
        self.tmpdir.cleanup()

    def test_settings_masks_gemini_api_key(self):
        with patch("app.check_permissions", return_value={"screen_recording": True, "accessibility": True}):
            res = self.client.post(
                "/api/settings",
                json={"gemini_api_key": "AIzaSySecretKey9876", "lang": "en"},
            )
            data = res.get_json()
            self.assertTrue(data["ok"])
            self.assertNotIn("gemini_api_key", data["settings"])
            self.assertTrue(data["settings"]["has_gemini_api_key"])
            self.assertEqual(data["settings"]["gemini_api_key_source"], "config")
            self.assertEqual(data["settings"]["gemini_api_key_hint"], "••••9876")

            res_get = self.client.get("/api/settings")
            data_get = res_get.get_json()
            self.assertNotIn("gemini_api_key", data_get["settings"])
            self.assertTrue(data_get["settings"]["has_gemini_api_key"])

    def test_ai_suggest_missing_key_bilingual(self):
        folder = os.path.join(self.tmpdir.name, "shots")
        os.makedirs(folder, exist_ok=True)
        fname = "Screenshot 2026-01-01 at 10.00.01.png"
        with open(os.path.join(folder, fname), "wb") as fp:
            fp.write(TINY_PNG)
        app_module.state["folder_path"] = folder
        app_module.state["files"] = [fname]

        res_en = self.client.post("/api/ai/suggest-names", json={"lang": "en"})
        data_en = res_en.get_json()
        self.assertFalse(data_en["ok"])
        self.assertEqual(data_en["code"], "missing_api_key")

        res_vi = self.client.post("/api/ai/suggest-names", json={"lang": "vi"})
        data_vi = res_vi.get_json()
        self.assertFalse(data_vi["ok"])
        self.assertEqual(data_vi["code"], "missing_api_key")
        self.assertNotEqual(data_en["message"], data_vi["message"])

    def test_ai_rename_custom_two_step_and_traversal_guard(self):
        folder = os.path.join(self.tmpdir.name, "shots")
        os.makedirs(folder, exist_ok=True)
        f1 = "Screenshot 2026-01-01 at 10.00.01.png"
        f2 = "Screenshot 2026-01-01 at 10.00.02.png"
        for name in (f1, f2):
            with open(os.path.join(folder, name), "wb") as fp:
                fp.write(TINY_PNG)
        app_module.state["folder_path"] = folder
        app_module.state["files"] = [f1, f2]

        # Path traversal attempt must fail
        bad = self.client.post(
            "/api/ai/rename-custom",
            json={"pairs": [{"old_name": f1, "new_name": "../evil.png"}], "lang": "en"},
        )
        self.assertFalse(bad.get_json()["ok"])

        # Valid AI rename
        ok_res = self.client.post(
            "/api/ai/rename-custom",
            json={
                "pairs": [
                    {"old_name": f1, "new_name": "01_intro.png"},
                    {"old_name": f2, "new_name": "02_architecture.png"},
                ],
                "lang": "en",
            },
        )
        ok_data = ok_res.get_json()
        self.assertTrue(ok_data["ok"])
        self.assertEqual(ok_data["success"], 2)
        self.assertTrue(os.path.isfile(os.path.join(folder, "01_intro.png")))
        self.assertTrue(os.path.isfile(os.path.join(folder, "02_architecture.png")))

    def test_ai_summarize_endpoint(self):
        folder = os.path.join(self.tmpdir.name, "shots")
        os.makedirs(folder, exist_ok=True)
        f1 = "Screenshot 2026-01-01 at 10.00.01.png"
        with open(os.path.join(folder, f1), "wb") as fp:
            fp.write(TINY_PNG)
        app_module.state["folder_path"] = folder
        app_module.state["files"] = [f1]
        config_store.save_config({"gemini_api_key": "AIzaSyTest123456"})

        with patch("app.summarize_screenshots", return_value=("## Summary\n- Item", 1)):
            res = self.client.post("/api/ai/summarize", json={"lang": "en"})
        data = res.get_json()
        self.assertTrue(data["ok"])
        self.assertEqual(data["count"], 1)
        self.assertIn("Summary", data["summary"])

    def test_en_vi_i18n_parity_for_ai_keys(self):
        app_js = (PROJECT_ROOT / "static" / "app.js").read_text(encoding="utf-8")
        index_html = (PROJECT_ROOT / "templates" / "index.html").read_text(encoding="utf-8")

        en_block = re.search(r"en:\s*\{(.*?)\n\s*\},\n\s*vi:", app_js, re.S)
        vi_block = re.search(r"vi:\s*\{(.*?)\n\s*\}\n\};", app_js, re.S)
        self.assertIsNotNone(en_block)
        self.assertIsNotNone(vi_block)

        en_keys = set(re.findall(r"^\s*([a-zA-Z0-9_]+)\s*:", en_block.group(1), re.M))
        vi_keys = set(re.findall(r"^\s*([a-zA-Z0-9_]+)\s*:", vi_block.group(1), re.M))
        self.assertEqual(en_keys, vi_keys)

        html_keys = set(re.findall(r'data-i18n(?:|-placeholder|-title)="([^"]+)"', index_html))
        missing = html_keys - en_keys
        self.assertEqual(missing, set(), f"Missing i18n keys in app.js: {missing}")


if __name__ == "__main__":
    unittest.main()
