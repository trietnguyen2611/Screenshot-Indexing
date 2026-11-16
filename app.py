import atexit
import json
import os
import re
import subprocess
import sys
import time
import tempfile
import unicodedata

if "--overlay-picker" in sys.argv:
    idx = sys.argv.index("--overlay-picker")
    target = sys.argv[idx + 1] if idx + 1 < len(sys.argv) else "region"
    from services.macos_overlay import run_overlay_cli
    sys.exit(run_overlay_cli(target))

from flask import Flask, Response, render_template, jsonify, request, send_from_directory

from services.afm_summarizer import (
    AFMSummarizerError,
    check_afm_availability,
    stream_summarize_with_afm,
    summarize_with_afm,
)
from services.config_store import load_config, reset_config, save_config
from services.macos_capture import (
    capture_controller,
    capture_fullscreen_preview,
    cleanup_preview_file,
)
from services.macos_hotkey import global_hotkey_manager
from services.macos_input import resolve_key_code
from services.macos_overlay import pick_screen_overlay
from services.macos_permissions import check_permissions

VERSION = os.environ.get("APP_VERSION", "1.0.1").lstrip("v")

if getattr(sys, 'frozen', False):
    if sys.platform == 'darwin':
        sys.stdout = open(os.devnull, 'w')
        sys.stderr = open(os.devnull, 'w')
    template_folder = os.path.join(sys._MEIPASS, 'templates')
    static_folder = os.path.join(sys._MEIPASS, 'static')
    app = Flask(__name__, template_folder=template_folder, static_folder=static_folder)
else:
    app = Flask(__name__)


def get_msg(key, lang):
    """Return localized UI/API message for 'en' or 'vi' (defaults to 'en')."""
    msgs = {
        "path_not_exist": {"vi": "Đường dẫn không tồn tại", "en": "Path does not exist"},
        "no_permission": {"vi": "Không có quyền truy cập", "en": "Permission denied"},
        "folder_not_exist": {"vi": "Thư mục không tồn tại", "en": "Folder does not exist"},
        "no_files": {"vi": "Không có file để đổi tên", "en": "No files to rename"},
        "error_prefix": {"vi": "Lỗi", "en": "Error"},
        "rename_success": {"vi": "Đã đổi tên {success_count}/{count} file thành công!", "en": "Successfully renamed {success_count}/{count} files!"},
        "settings_saved": {"vi": "Đã lưu cài đặt thành công", "en": "Settings saved successfully"},
        "settings_save_failed": {"vi": "Không thể lưu cài đặt", "en": "Failed to save settings"},
        "capture_folder_required": {"vi": "Vui lòng chọn thư mục lưu ảnh chụp", "en": "Please select a save folder for screenshots"},
        "capture_invalid_region": {"vi": "Vùng chụp không hợp lệ (chiều rộng và chiều cao tối thiểu 10 px)", "en": "Invalid capture region (minimum width and height of 10 px)"},
        "capture_started": {"vi": "Đã bắt đầu tự động chụp màn hình", "en": "Auto capture started"},
        "capture_already_running": {"vi": "Tiến trình tự động chụp đang chạy", "en": "Auto capture is already running"},
        "capture_start_failed": {"vi": "Không thể bắt đầu tự động chụp", "en": "Failed to start auto capture"},
        "capture_stopped": {"vi": "Đã dừng tự động chụp màn hình", "en": "Auto capture stopped"},
        "preview_failed": {"vi": "Không thể chụp ảnh xem trước toàn màn hình", "en": "Failed to capture full-screen preview"},
        "overlay_cancelled": {"vi": "Đã hủy chọn trên màn hình", "en": "Screen selection cancelled"},
        "overlay_failed": {"vi": "Không thể mở lớp phủ chọn trên màn hình", "en": "Failed to launch screen overlay picker"},
        "permission_denied_capture": {"vi": "Thiếu quyền Ghi màn hình (Screen Recording) trên macOS", "en": "Screen Recording permission is required on macOS"},
        "accessibility_warning": {"vi": "Vui lòng cấp quyền Trợ năng (Accessibility) trong Cài đặt hệ thống để tự động lật trang hoạt động", "en": "Please grant Accessibility permission in System Settings for Auto Page-Turn to work"},
        "file_not_found": {"vi": "Không tìm thấy tệp ảnh", "en": "Image file not found"},
        "afm_summarize_success": {"vi": "Đã tóm tắt {count} ảnh vào Ghi chú bằng Apple Foundation Model", "en": "Summarized {count} screenshots into Notes with Apple Foundation Model"},
        "afm_unavailable": {"vi": "Apple Foundation Model chưa sẵn sàng trên máy này", "en": "Apple Foundation Model is not available on this Mac"},
        "afm_failed": {"vi": "Tóm tắt AFM thất bại", "en": "AFM summarization failed"},
    }
    entry = msgs.get(key, {})
    return entry.get(lang, entry.get("en"))


# Store current state
state = {
    "folder_path": "",
    "files": [],
    "region_revision": 0,
    "last_preview_meta": None,
}


def _on_global_overlay_hotkey():
    """Triggered from macOS global hotkey even when another app (e.g. Safari) is focused."""
    res = pick_screen_overlay("region")
    if not res.get("ok") or res.get("cancelled"):
        return
    region = res.get("region")
    if isinstance(region, dict):
        save_config({"region": region})
    preview_res = capture_fullscreen_preview(delay_sec=0.1)
    if isinstance(preview_res, dict) and preview_res.get("ok"):
        state["last_preview_meta"] = {
            "screen_width": preview_res.get("screen_width"),
            "screen_height": preview_res.get("screen_height"),
            "image_width": preview_res.get("image_width"),
            "image_height": preview_res.get("image_height"),
            "scale_factor": preview_res.get("scale_factor"),
            "origin_x": preview_res.get("origin_x", 0),
            "origin_y": preview_res.get("origin_y", 0),
        }
    state["region_revision"] = int(state.get("region_revision", 0)) + 1


global_hotkey_manager.set_callback(_on_global_overlay_hotkey)


@app.route("/api/image")
def get_image():
    filename = request.args.get("name")
    folder = state.get("folder_path")
    if not folder or not filename or not os.path.isdir(folder):
        return "File not found", 404
    return send_from_directory(folder, filename)


def is_screenshot_file(filename):
    if not filename.lower().endswith('.png'):
        return False
    norm_nfc = unicodedata.normalize('NFC', filename).lower()
    norm_nfd = unicodedata.normalize('NFD', filename).lower()
    prefixes = ["screenshot", "ảnh màn hình", "anh man hinh"]
    for pref in prefixes:
        pref_nfc = unicodedata.normalize('NFC', pref).lower()
        pref_nfd = unicodedata.normalize('NFD', pref).lower()
        if norm_nfc.startswith(pref_nfc) or norm_nfd.startswith(pref_nfd):
            return True
    return False


def get_sort_key(filename):
    match = re.search(r'(\d+)\.(\d+)\.(\d+)\.\w+$', filename)
    if match:
        hours = int(match.group(1))
        minutes = int(match.group(2))
        seconds = int(match.group(3))
        return hours * 3600 + minutes * 60 + seconds
    return 0


def get_seconds_display(filename):
    match = re.search(r'(\d+)\.(\d+)\.(\d+)\.\w+$', filename)
    if match:
        return match.group(3)
    return "?"


@app.route("/")
def index():
    return render_template("index.html", version=VERSION)


@app.route("/api/version")
def get_version():
    return jsonify({"version": VERSION})


@app.route("/api/browse", methods=["POST"])
def browse_directory():
    """List subdirectories at a given path for the web-based folder browser."""
    data = request.get_json(silent=True) or {}
    path = data.get("path", os.path.expanduser("~"))

    if not os.path.isdir(path):
        return jsonify({"ok": False, "message": get_msg("path_not_exist", data.get("lang", "en"))})

    try:
        entries = []
        for name in sorted(os.listdir(path)):
            full = os.path.join(path, name)
            if os.path.isdir(full) and not name.startswith("."):
                entries.append(name)
        parent = os.path.dirname(path)
        return jsonify({
            "ok": True,
            "current": path,
            "parent": parent if parent != path else None,
            "dirs": entries
        })
    except PermissionError:
        return jsonify({"ok": False, "message": get_msg("no_permission", data.get("lang", "en"))})


@app.route("/api/browse-native", methods=["POST"])
def browse_native_directory():
    """Open the native macOS Finder folder chooser dialog and return the selected POSIX path."""
    data = request.get_json(silent=True) or {}
    lang = data.get("lang", "en")
    initial_path = (data.get("path") or "").strip()
    prompt_text = "Chọn thư mục" if lang == "vi" else "Select Folder"

    if initial_path and os.path.isdir(initial_path):
        escaped_path = initial_path.replace("\\", "\\\\").replace('"', '\\"')
        script = f'POSIX path of (choose folder with prompt "{prompt_text}" default location POSIX file "{escaped_path}")'
    else:
        script = f'POSIX path of (choose folder with prompt "{prompt_text}")'

    try:
        proc = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        return jsonify({"ok": False, "message": f"{get_msg('error_prefix', lang)}: {exc}"})

    if proc.returncode != 0:
        stderr_lower = (proc.stderr or "").lower()
        if "-128" in stderr_lower or "user canceled" in stderr_lower or "user cancelled" in stderr_lower:
            return jsonify({"ok": True, "cancelled": True})
        return jsonify({"ok": False, "message": f"{get_msg('error_prefix', lang)}: {(proc.stderr or '').strip() or 'Dialog failed'}"})

    selected = (proc.stdout or "").strip()
    if len(selected) > 1 and selected.endswith("/"):
        selected = selected[:-1]
    return jsonify({"ok": True, "cancelled": False, "path": selected})


@app.route("/api/scan", methods=["POST"])
def scan_files():
    """Scan folder for screenshot files."""
    data = request.get_json(silent=True) or {}
    folder = data.get("folder", state["folder_path"])

    if not folder or not os.path.isdir(folder):
        return jsonify({"ok": False, "message": get_msg("folder_not_exist", data.get("lang", "en"))})

    state["folder_path"] = folder

    files = [
        f for f in os.listdir(folder)
        if is_screenshot_file(f)
    ]
    files.sort(key=get_sort_key)

    file_list = []
    for i, f in enumerate(files, 1):
        sec = get_seconds_display(f)
        file_list.append({
            "index": i,
            "name": f,
            "seconds": sec
        })

    state["files"] = files
    return jsonify({"ok": True, "files": file_list, "count": len(files)})


@app.route("/api/rename", methods=["POST"])
def rename_files():
    """Rename files with the given range."""
    data = request.get_json(silent=True) or {}
    lang = data.get("lang", "en")
    folder = state["folder_path"]
    files = state["files"]

    if not files:
        return jsonify({"ok": False, "message": get_msg("no_files", lang)})

    if not folder or not os.path.isdir(folder):
        return jsonify({"ok": False, "message": get_msg("folder_not_exist", lang)})

    try:
        start_num = int(data.get("start"))
        end_num = int(data.get("end"))
    except (TypeError, ValueError):
        return jsonify({"ok": False, "message": f"{get_msg('error_prefix', lang)}: Invalid start/end range"})

    if start_num < 0 or end_num < start_num:
        return jsonify({"ok": False, "message": f"{get_msg('error_prefix', lang)}: Invalid start/end range"})

    total_numbers = end_num - start_num + 1
    count = min(len(files), total_numbers)

    rename_pairs = []
    for i in range(count):
        old_name = files[i]
        new_name = f"{start_num + i}.png"
        rename_pairs.append((old_name, new_name))

    # Step 1: Rename to temp names
    temp_pairs = []
    try:
        for old_name, new_name in rename_pairs:
            temp_name = f"__temp_rename_{new_name}"
            old_path = os.path.join(folder, old_name)
            temp_path = os.path.join(folder, temp_name)
            os.rename(old_path, temp_path)
            temp_pairs.append((old_name, temp_name, new_name))
    except Exception as e:
        return jsonify({"ok": False, "message": f"{get_msg('error_prefix', lang)}: {str(e)}"})

    # Step 2: Rename from temp to final
    success_count = 0
    for _old_name, temp_name, new_name in temp_pairs:
        temp_path = os.path.join(folder, temp_name)
        new_path = os.path.join(folder, new_name)
        if os.path.exists(new_path):
            continue
        os.rename(temp_path, new_path)
        success_count += 1

    state["files"] = []
    return jsonify({
        "ok": True,
        "success": success_count,
        "total": count,
        "message": get_msg("rename_success", lang).format(success_count=success_count, count=count)
    })


def _extract_settings_updates(data: dict) -> dict:
    """Build a sanitized settings update dict from JSON request payload."""
    payload = {}
    for key in ("interval_sec", "max_shots", "countdown_sec", "sound_enabled", "region"):
        if key in data:
            payload[key] = data[key]

    if "save_folder" in data:
        raw_folder = data.get("save_folder")
        if isinstance(raw_folder, str):
            cleaned = raw_folder.strip()
            payload["save_folder"] = os.path.expanduser(cleaned) if cleaned else ""
        else:
            payload["save_folder"] = ""

    if isinstance(data.get("page_turn"), dict):
        pt = dict(data["page_turn"])
        if "key_name" in pt:
            pt["key_code"] = resolve_key_code(pt.get("key_name", "ArrowRight"), pt.get("key_code"))
        elif "key_code" in pt:
            pt["key_code"] = resolve_key_code("", pt.get("key_code"))
        payload["page_turn"] = pt

    return payload


@app.route("/api/settings", methods=["GET"])
def get_settings():
    """Return persisted auto-capture settings and current TCC permissions."""
    return jsonify({
        "ok": True,
        "settings": load_config(),
        "permissions": check_permissions(prompt=False),
    })


@app.route("/api/settings", methods=["POST"])
def update_settings():
    """Validate, create save folder if provided, and persist settings."""
    data = request.get_json(silent=True) or {}
    lang = data.get("lang", "en")

    payload = _extract_settings_updates(data)
    save_folder = payload.get("save_folder")
    if isinstance(save_folder, str) and save_folder:
        try:
            os.makedirs(save_folder, exist_ok=True)
        except OSError as e:
            return jsonify({
                "ok": False,
                "message": f"{get_msg('settings_save_failed', lang)}: {str(e)}",
            })

    try:
        saved = save_config(payload)
    except OSError as e:
        return jsonify({
            "ok": False,
            "message": f"{get_msg('settings_save_failed', lang)}: {str(e)}",
        })

    if saved.get("save_folder"):
        state["folder_path"] = saved["save_folder"]

    return jsonify({
        "ok": True,
        "settings": saved,
        "message": get_msg("settings_saved", lang),
    })


@app.route("/api/capture/permissions", methods=["POST"])
def capture_permissions():
    """Check (and optionally prompt for) macOS Screen Recording & Accessibility permissions."""
    data = request.get_json(silent=True) or {}
    prompt = bool(data.get("prompt", False))
    return jsonify({
        "ok": True,
        "permissions": check_permissions(prompt=prompt),
    })


@app.route("/api/capture/open-permission-settings", methods=["POST"])
def open_permission_settings():
    """Open macOS System Settings directly to Screen Recording or Accessibility Privacy pane."""
    data = request.get_json(silent=True) or {}
    perm = (data.get("permission") or "").strip()
    lang = data.get("lang", "en")

    urls = {
        "screen_recording": "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
        "accessibility": "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
    }
    target_url = urls.get(perm)
    if not target_url:
        return jsonify({"ok": False, "message": f"{get_msg('error_prefix', lang)}: Unknown permission"})

    try:
        subprocess.Popen(["open", target_url])
    except OSError as exc:
        return jsonify({"ok": False, "message": f"{get_msg('error_prefix', lang)}: {exc}"})

    return jsonify({"ok": True})


@app.route("/api/capture/preview-screen", methods=["POST"])
def capture_preview_screen():
    """Capture full-screen preview image and display coordinate metadata."""
    data = request.get_json(silent=True) or {}
    lang = data.get("lang", "en")
    try:
        delay_sec = float(data.get("delay_sec", 0.2))
    except (TypeError, ValueError):
        delay_sec = 0.2

    res = capture_fullscreen_preview(delay_sec=delay_sec)
    if not res or not res.get("ok"):
        perms = check_permissions(prompt=False)
        base_msg = (
            get_msg("permission_denied_capture", lang)
            if not perms.get("screen_recording")
            else get_msg("preview_failed", lang)
        )
        err = res.get("error") if isinstance(res, dict) else None
        msg = f"{base_msg}: {err}" if err else base_msg
        return jsonify({
            "ok": False,
            "message": msg,
            "permissions": perms,
        })

    return jsonify({
        "ok": True,
        "image_url": f"/api/capture/preview-image?t={int(time.time() * 1000)}",
        "screen_width": res["screen_width"],
        "screen_height": res["screen_height"],
        "image_width": res["image_width"],
        "image_height": res["image_height"],
        "scale_factor": res["scale_factor"],
        "origin_x": res.get("origin_x", 0),
        "origin_y": res.get("origin_y", 0),
    })


@app.route("/api/capture/preview-image")
def get_capture_preview_image():
    """Serve full-screen preview PNG from the system temp directory."""
    lang = request.args.get("lang", "en")
    temp_dir = tempfile.gettempdir()
    preview_name = "screenshot_indexing_preview.png"
    preview_path = os.path.join(temp_dir, preview_name)
    if not os.path.isfile(preview_path):
        return get_msg("file_not_found", lang), 404
    return send_from_directory(temp_dir, preview_name, max_age=0)


@app.route("/api/capture/pick-overlay", methods=["POST"])
def capture_pick_overlay():
    """Launch native macOS transparent overlay picker for region or click target."""
    data = request.get_json(silent=True) or {}
    lang = data.get("lang", "en")
    target = "click" if data.get("target") == "click" else "region"

    res = pick_screen_overlay(target)
    if not isinstance(res, dict):
        return jsonify({
            "ok": False,
            "cancelled": False,
            "message": get_msg("overlay_failed", lang),
        })

    if res.get("ok"):
        updates = {}
        if isinstance(res.get("region"), dict):
            updates["region"] = res["region"]
        if isinstance(res.get("click_point"), dict):
            cp = res["click_point"]
            updates["page_turn"] = {
                "click_x": cp.get("click_x", 500),
                "click_y": cp.get("click_y", 500),
            }
        try:
            saved = save_config(updates)
        except OSError as e:
            return jsonify({
                "ok": False,
                "cancelled": False,
                "message": f"{get_msg('settings_save_failed', lang)}: {str(e)}",
            })
        return jsonify({
            "ok": True,
            "region": saved["region"],
            "click_point": {
                "click_x": saved["page_turn"]["click_x"],
                "click_y": saved["page_turn"]["click_y"],
            },
            "settings": saved,
        })

    if res.get("cancelled"):
        return jsonify({
            "ok": False,
            "cancelled": True,
            "message": get_msg("overlay_cancelled", lang),
        })

    err = res.get("message") or res.get("error") or ""
    msg = f"{get_msg('overlay_failed', lang)}: {err}" if err else get_msg("overlay_failed", lang)
    return jsonify({
        "ok": False,
        "cancelled": False,
        "message": msg,
    })


@app.route("/api/capture/start", methods=["POST"])
def capture_start():
    """Validate save folder and region, persist config, and start timed capture loop."""
    data = request.get_json(silent=True) or {}
    lang = data.get("lang", "en")

    current_status = capture_controller.get_status()
    if current_status.get("running"):
        return jsonify({
            "ok": False,
            "status": current_status,
            "message": get_msg("capture_already_running", lang),
        })

    current_cfg = load_config()
    updates = _extract_settings_updates(data)

    if "save_folder" in updates:
        raw_folder = updates["save_folder"]
    else:
        raw_folder = current_cfg.get("save_folder", "")
    raw_folder = raw_folder.strip() if isinstance(raw_folder, str) else ""

    if not raw_folder:
        return jsonify({"ok": False, "message": get_msg("capture_folder_required", lang)})

    expanded_folder = os.path.expanduser(raw_folder)
    updates["save_folder"] = expanded_folder

    merged_region = dict(current_cfg["region"])
    if isinstance(updates.get("region"), dict):
        merged_region.update(updates["region"])
    try:
        reg_w = float(merged_region.get("width", 0))
        reg_h = float(merged_region.get("height", 0))
    except (TypeError, ValueError):
        return jsonify({"ok": False, "message": get_msg("capture_invalid_region", lang)})

    if not (reg_w >= 10 and reg_h >= 10):
        return jsonify({"ok": False, "message": get_msg("capture_invalid_region", lang)})

    try:
        os.makedirs(expanded_folder, exist_ok=True)
        saved = save_config(updates)
    except OSError as e:
        return jsonify({
            "ok": False,
            "message": f"{get_msg('no_permission', lang)}: {str(e)}",
        })

    state["folder_path"] = saved["save_folder"]

    def _on_shot(folder_path, _filename):
        if folder_path:
            state["folder_path"] = folder_path

    perms = None
    if not app.config.get("TESTING"):
        perms = check_permissions(prompt=False)

    res = capture_controller.start(saved, on_shot_callback=_on_shot)
    if not res or not res.get("ok"):
        err = res.get("error") if isinstance(res, dict) else ""
        status = res.get("status", capture_controller.get_status()) if isinstance(res, dict) else capture_controller.get_status()
        if err == "already_running":
            return jsonify({
                "ok": False,
                "status": status,
                "message": get_msg("capture_already_running", lang),
            })
        msg = f"{get_msg('capture_start_failed', lang)}: {err}" if err else get_msg("capture_start_failed", lang)
        return jsonify({
            "ok": False,
            "status": status,
            "message": msg,
        })

    resp_payload = {
        "ok": True,
        "status": res["status"],
        "settings": saved,
        "message": get_msg("capture_started", lang),
    }
    if perms is not None:
        resp_payload["permissions"] = perms
        if saved.get("page_turn", {}).get("enabled", True) and not perms.get("accessibility"):
            resp_payload["accessibility_warning"] = get_msg("accessibility_warning", lang)
    return jsonify(resp_payload)


@app.route("/api/capture/stop", methods=["POST"])
def capture_stop():
    """Signal active capture loop to stop immediately."""
    data = request.get_json(silent=True) or {}
    lang = data.get("lang", "en")
    status = capture_controller.stop()
    return jsonify({
        "ok": True,
        "status": status,
        "message": get_msg("capture_stopped", lang),
    })


@app.route("/api/capture/hotkey", methods=["POST"])
def capture_hotkey():
    """Update the macOS system-wide global hotkey for the region overlay picker."""
    data = request.get_json(silent=True) or {}
    shortcut = global_hotkey_manager.update_shortcut(data.get("shortcut") or data)
    started = global_hotkey_manager.start()
    return jsonify({"ok": True, "shortcut": shortcut, "listening": started})


@app.route("/api/capture/status", methods=["GET"])
def capture_status():
    """Return current auto-capture worker status snapshot."""
    return jsonify({
        "ok": True,
        "status": capture_controller.get_status(),
        "region_revision": int(state.get("region_revision", 0)),
        "region": load_config().get("region"),
        "preview_meta": state.get("last_preview_meta"),
    })


@app.route("/api/capture/latest-image")
def get_capture_latest_image():
    """Serve a captured screenshot image safely from the configured save folder."""
    lang = request.args.get("lang", "en")
    filename = request.args.get("name", "")
    if (
        not filename
        or "/" in filename
        or "\\" in filename
        or os.path.basename(filename) != filename
        or filename in (".", "..")
    ):
        return get_msg("file_not_found", lang), 404

    raw_folder = request.args.get("folder", "").strip()
    if raw_folder:
        folder = os.path.expanduser(raw_folder)
    else:
        folder = load_config().get("save_folder") or state.get("folder_path", "")

    if not folder or not os.path.isdir(folder):
        return get_msg("file_not_found", lang), 404

    full_path = os.path.join(folder, filename)
    if not os.path.isfile(full_path):
        return get_msg("file_not_found", lang), 404

    return send_from_directory(folder, filename, max_age=0)


@app.route("/api/afm/status", methods=["GET"])
def afm_status():
    """Return on-device Apple Foundation Model availability status."""
    return jsonify({"ok": True, **check_afm_availability()})


@app.route("/api/afm/summarize", methods=["POST"])
def afm_summarize():
    """Summarize scanned screenshots into Markdown notes using Vision OCR + on-device AFM."""
    data = request.get_json(silent=True) or {}
    lang = data.get("lang", "en")
    folder = state.get("folder_path", "")
    files = list(state.get("files") or [])

    if not files:
        return jsonify({"ok": False, "message": get_msg("no_files", lang)})
    if not folder or not os.path.isdir(folder):
        return jsonify({"ok": False, "message": get_msg("folder_not_exist", lang)})

    requested_files = data.get("filenames")
    if isinstance(requested_files, list) and requested_files:
        allowed = set(files)
        target_files = [f for f in requested_files if isinstance(f, str) and f in allowed]
    else:
        target_files = files

    if not target_files:
        return jsonify({"ok": False, "message": get_msg("no_files", lang)})

    try:
        summary, count = summarize_with_afm(folder=folder, filenames=target_files, lang=lang)
    except AFMSummarizerError as exc:
        if exc.code in (
            "device_not_eligible",
            "apple_intelligence_not_enabled",
            "model_not_ready",
            "helper_missing",
            "unavailable",
        ):
            return jsonify({
                "ok": False,
                "code": exc.code,
                "message": f"{get_msg('afm_unavailable', lang)} ({exc.code})",
            })
        return jsonify({
            "ok": False,
            "code": exc.code,
            "message": f"{get_msg('afm_failed', lang)}: {exc.message}",
        })

    return jsonify({
        "ok": True,
        "summary": summary,
        "count": count,
        "message": get_msg("afm_summarize_success", lang).format(count=count),
    })


@app.route("/api/afm/summarize-stream", methods=["POST"])
def afm_summarize_stream():
    """Stream Vision OCR + on-device AFM summarization via Server-Sent Events."""
    data = request.get_json(silent=True) or {}
    lang = data.get("lang", "en")
    folder = state.get("folder_path", "")
    files = list(state.get("files") or [])

    if not files:
        return jsonify({"ok": False, "message": get_msg("no_files", lang)})
    if not folder or not os.path.isdir(folder):
        return jsonify({"ok": False, "message": get_msg("folder_not_exist", lang)})

    requested_files = data.get("filenames")
    if isinstance(requested_files, list) and requested_files:
        allowed = set(files)
        target_files = [f for f in requested_files if isinstance(f, str) and f in allowed]
    else:
        target_files = files

    if not target_files:
        return jsonify({"ok": False, "message": get_msg("no_files", lang)})

    def _generate():
        for evt in stream_summarize_with_afm(folder=folder, filenames=target_files, lang=lang):
            if evt.get("type") == "done":
                count = int(evt.get("processed") or len(target_files))
                evt["message"] = get_msg("afm_summarize_success", lang).format(count=count)
            elif evt.get("type") == "error":
                reason = evt.get("reason") or "afm_error"
                if reason in (
                    "device_not_eligible",
                    "apple_intelligence_not_enabled",
                    "model_not_ready",
                    "helper_missing",
                    "unavailable",
                ):
                    evt["message"] = f"{get_msg('afm_unavailable', lang)} ({reason})"
                else:
                    evt["message"] = f"{get_msg('afm_failed', lang)}: {evt.get('error') or reason}"
            yield f"data: {json.dumps(evt, ensure_ascii=False)}\n\n"

    return Response(
        _generate(),
        mimetype="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


def cleanup_session():
    """Stop active capture, wipe persisted session config/preview, and reset state."""
    try:
        capture_controller.reset()
    except Exception:
        pass
    try:
        reset_config()
    except Exception:
        pass
    try:
        cleanup_preview_file()
    except Exception:
        pass
    try:
        global_hotkey_manager.stop()
    except Exception:
        pass
    state["folder_path"] = ""
    state["files"] = []
    state["region_revision"] = 0


if __name__ == "__main__":
    import threading
    import webview

    cleanup_session()
    atexit.register(cleanup_session)
    global_hotkey_manager.start()

    # Start Flask in a background thread
    flask_thread = threading.Thread(
        target=lambda: app.run(host="127.0.0.1", port=5050, debug=False, use_reloader=False)
    )
    flask_thread.daemon = True
    flask_thread.start()

    # Open PyWebView window
    webview.create_window(f"Screenshot Indexing v{VERSION}", "http://127.0.0.1:5050", width=1200, height=800)
    try:
        webview.start()
    finally:
        cleanup_session()
