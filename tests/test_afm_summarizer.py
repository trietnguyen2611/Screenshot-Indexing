"""Unit tests for on-device Apple Foundation Models (AFM) summarizer and Settings i18n parity."""

import json
import os
import re
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import app as app_module  # noqa: E402
from services.afm_summarizer import (  # noqa: E402
    AFMSummarizerError,
    check_afm_availability,
    get_afm_helper_path,
    summarize_with_afm,
)

TINY_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\rIDATx\x9cc`\x00\x00\x00"
    b"\x02\x00\x01H\xaf\xa4q\x00\x00\x00\x00IEND\xaeB`\x82"
)


class TestAFMSummarizerService(unittest.TestCase):
    def test_helper_binary_exists_and_check_runs(self):
        helper = get_afm_helper_path()
        self.assertTrue(os.path.isfile(helper), f"Expected compiled afm_helper at {helper}")
        status = check_afm_availability()
        self.assertIn("available", status)
        self.assertIn("reason", status)

    def test_check_afm_availability_handles_missing_binary(self):
        with patch("services.afm_summarizer.get_afm_helper_path", return_value="/nonexistent/afm_helper"):
            status = check_afm_availability()
        self.assertFalse(status["available"])
        self.assertEqual(status["reason"], "helper_missing")

    def test_summarize_with_afm_success_and_unavailable(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            fname = "Screenshot 2026-01-01 at 10.00.01.png"
            with open(os.path.join(tmpdir, fname), "wb") as fp:
                fp.write(TINY_PNG)

            fake_ok = SimpleNamespace(
                returncode=0,
                stdout=json.dumps({
                    "ok": True,
                    "available": True,
                    "reason": "available",
                    "summary": "## Notes\n- Local AFM summary",
                    "processed": 1,
                }),
                stderr="",
            )
            with patch("services.afm_summarizer.subprocess.run", return_value=fake_ok) as run_mock:
                summary, count = summarize_with_afm(tmpdir, [fname], lang="vi")
            self.assertEqual(count, 1)
            self.assertIn("Local AFM summary", summary)
            sent_payload = json.loads(run_mock.call_args.kwargs["input"])
            self.assertEqual(sent_payload["lang"], "vi")

            fake_unavail = SimpleNamespace(
                returncode=0,
                stdout=json.dumps({
                    "ok": False,
                    "available": False,
                    "reason": "apple_intelligence_not_enabled",
                    "error": "Apple Foundation Model unavailable",
                }),
                stderr="",
            )
            with patch("services.afm_summarizer.subprocess.run", return_value=fake_unavail):
                with self.assertRaises(AFMSummarizerError) as ctx:
                    summarize_with_afm(tmpdir, [fname], lang="en")
                self.assertEqual(ctx.exception.code, "apple_intelligence_not_enabled")


class TestFlaskAFMEndpointsAndI18n(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        app_module.state["folder_path"] = ""
        app_module.state["files"] = []
        self.client = app_module.app.test_client()

    def tearDown(self):
        app_module.state["folder_path"] = ""
        app_module.state["files"] = []
        self.tmpdir.cleanup()

    def test_afm_status_endpoint(self):
        with patch("app.check_afm_availability", return_value={"available": True, "reason": "available"}):
            res = self.client.get("/api/afm/status")
        data = res.get_json()
        self.assertTrue(data["ok"])
        self.assertTrue(data["available"])
        self.assertEqual(data["reason"], "available")

    def test_afm_summarize_endpoint(self):
        fname = "Screenshot 2026-01-01 at 10.00.01.png"
        with open(os.path.join(self.tmpdir.name, fname), "wb") as fp:
            fp.write(TINY_PNG)
        app_module.state["folder_path"] = self.tmpdir.name
        app_module.state["files"] = [fname]

        with patch("app.summarize_with_afm", return_value=("## Page 1\n- Bullet", 1)):
            res = self.client.post("/api/afm/summarize", json={"lang": "vi", "filenames": [fname]})
        data = res.get_json()
        self.assertTrue(data["ok"])
        self.assertEqual(data["count"], 1)
        self.assertIn("Bullet", data["summary"])

    def test_en_vi_i18n_parity(self):
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
