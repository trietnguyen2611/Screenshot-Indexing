"""On-device Apple Foundation Models (AFM) + Vision OCR summarizer for macOS Apple Silicon."""

import json
import os
import subprocess
import sys


class AFMSummarizerError(Exception):
    """Error raised when on-device AFM availability check or summarization fails."""

    def __init__(self, code: str, message: str = ""):
        super().__init__(message or code)
        self.code = code
        self.message = message or code


def get_afm_helper_path() -> str:
    """Resolve the bundled arm64 afm_helper binary path in both source and frozen PyInstaller modes."""
    if getattr(sys, "frozen", False):
        base_dir = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
        candidate = os.path.join(base_dir, "services", "bin", "afm_helper")
        if os.path.isfile(candidate):
            return candidate
    source_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(source_dir, "bin", "afm_helper")


def check_afm_availability() -> dict:
    """Query the on-device Apple Foundation Model availability status."""
    helper = get_afm_helper_path()
    if not os.path.isfile(helper):
        return {
            "available": False,
            "reason": "helper_missing",
            "binary_path": helper,
        }

    try:
        proc = subprocess.run(
            [helper, "--check"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        return {
            "available": False,
            "reason": "exec_error",
            "error": str(exc),
        }

    if proc.returncode != 0 or not proc.stdout.strip():
        return {
            "available": False,
            "reason": "exec_error",
            "error": (proc.stderr or "").strip() or f"exit={proc.returncode}",
        }

    try:
        data = json.loads(proc.stdout.strip())
    except json.JSONDecodeError:
        return {
            "available": False,
            "reason": "invalid_response",
        }

    return {
        "available": bool(data.get("available", False)),
        "reason": data.get("reason") or ("available" if data.get("available") else "unavailable"),
    }


def summarize_with_afm(folder: str, filenames: list[str], lang: str = "en") -> tuple[str, int]:
    """Run Vision OCR + on-device AFM summarization on the given screenshot filenames."""
    helper = get_afm_helper_path()
    if not os.path.isfile(helper):
        raise AFMSummarizerError("helper_missing", "afm_helper binary not found")

    image_paths = []
    for name in filenames:
        full_path = os.path.join(folder, name)
        if os.path.isfile(full_path):
            image_paths.append(full_path)

    if not image_paths:
        raise AFMSummarizerError("no_images", "No valid image files found")

    payload = json.dumps({
        "images": image_paths,
        "lang": "vi" if lang == "vi" else "en",
    })

    try:
        proc = subprocess.run(
            [helper],
            input=payload,
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise AFMSummarizerError("timeout", "AFM summarization timed out") from exc
    except OSError as exc:
        raise AFMSummarizerError("exec_error", str(exc)) from exc

    raw_out = (proc.stdout or "").strip()
    if not raw_out:
        err_msg = (proc.stderr or "").strip() or f"exit={proc.returncode}"
        raise AFMSummarizerError("exec_error", err_msg)

    try:
        data = json.loads(raw_out)
    except json.JSONDecodeError as exc:
        raise AFMSummarizerError("invalid_response", f"Invalid JSON from afm_helper: {exc}") from exc

    if not data.get("ok"):
        reason = data.get("reason") or "afm_error"
        err_msg = data.get("error") or reason
        raise AFMSummarizerError(reason, err_msg)

    summary = (data.get("summary") or "").strip()
    if not summary:
        raise AFMSummarizerError("empty_summary", "Empty summary returned by AFM")

    processed = int(data.get("processed") or len(image_paths))
    return summary, processed


def stream_summarize_with_afm(folder: str, filenames: list[str], lang: str = "en"):
    """Stream Vision OCR + on-device AFM summarization events as dicts."""
    helper = get_afm_helper_path()
    if not os.path.isfile(helper):
        yield {"type": "error", "reason": "helper_missing", "error": "afm_helper binary not found"}
        return

    image_paths = []
    for name in filenames:
        full_path = os.path.join(folder, name)
        if os.path.isfile(full_path):
            image_paths.append(full_path)

    if not image_paths:
        yield {"type": "error", "reason": "no_images", "error": "No valid image files found"}
        return

    payload = json.dumps({
        "images": image_paths,
        "lang": "vi" if lang == "vi" else "en",
    })

    try:
        proc = subprocess.Popen(
            [helper, "--stream"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
    except OSError as exc:
        yield {"type": "error", "reason": "exec_error", "error": str(exc)}
        return

    try:
        if proc.stdin:
            proc.stdin.write(payload)
            proc.stdin.close()

        if proc.stdout:
            for line in proc.stdout:
                cleaned = line.strip()
                if not cleaned:
                    continue
                try:
                    evt = json.loads(cleaned)
                    if isinstance(evt, dict):
                        yield evt
                except json.JSONDecodeError:
                    continue

        proc.wait(timeout=10)
    except Exception as exc:
        try:
            proc.kill()
        except OSError:
            pass
        yield {"type": "error", "reason": "exec_error", "error": str(exc)}
