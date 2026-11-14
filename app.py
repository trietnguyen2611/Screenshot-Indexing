import os
import re
import json
import sys
import time
import tempfile
import unicodedata

if "--overlay-picker" in sys.argv:
    idx = sys.argv.index("--overlay-picker")
    target = sys.argv[idx + 1] if idx + 1 < len(sys.argv) else "region"
    from services.macos_overlay import run_overlay_cli
    sys.exit(run_overlay_cli(target))

from flask import Flask, render_template, jsonify, request, send_from_directory

from services.config_store import load_config, save_config
from services.macos_capture import capture_controller, capture_fullscreen_preview
from services.macos_input import resolve_key_code
from services.macos_overlay import pick_screen_overlay
from services.macos_permissions import check_permissions

VERSION = os.environ.get("APP_VERSION", "1.0.3").lstrip("v")

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
        "file_not_found": {"vi": "Không tìm thấy tệp ảnh", "en": "Image file not found"},
    }
    entry = msgs.get(key, {})
    return entry.get(lang, entry.get("en"))


# Store current state
state = {
    "folder_path": "",
    "files": []
}


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
    start_num = data.get("start")
    end_num = data.get("end")
    folder = state["folder_path"]
    files = state["files"]

    if not files:
        return jsonify({"ok": False, "message": get_msg("no_files", data.get("lang", "en"))})

    if not folder or not os.path.isdir(folder):
        return jsonify({"ok": False, "message": get_msg("folder_not_exist", data.get("lang", "en"))})

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
            temp_pairs.append((temp_name, new_name))
    except Exception as e:
        return jsonify({"ok": False, "message": f"{get_msg('error_prefix', data.get('lang', 'en'))}: {str(e)}"})

    # Step 2: Rename from temp to final
    success_count = 0
    for temp_name, new_name in temp_pairs:
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
        "message": get_msg("rename_success", data.get("lang", "en")).format(success_count=success_count, count=count)
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

    return jsonify({
        "ok": True,
        "status": res["status"],
        "settings": saved,
        "message": get_msg("capture_started", lang),
    })


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


@app.route("/api/capture/status", methods=["GET"])
def capture_status():
    """Return current auto-capture worker status snapshot."""
    return jsonify({
        "ok": True,
        "status": capture_controller.get_status(),
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


if __name__ == "__main__":
    import threading
    import webview

    # Start Flask in a background thread
    flask_thread = threading.Thread(
        target=lambda: app.run(host="127.0.0.1", port=5050, debug=False, use_reloader=False)
    )
    flask_thread.daemon = True
    flask_thread.start()

    # Open PyWebView window
    webview.create_window(f"Screenshot Indexing v{VERSION}", "http://127.0.0.1:5050", width=1200, height=800)
    webview.start()
