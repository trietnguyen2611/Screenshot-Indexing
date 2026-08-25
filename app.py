import os
import re
import json
import sys
import unicodedata
from flask import Flask, render_template, jsonify, request, send_from_directory

VERSION = os.environ.get("APP_VERSION", "1.0.0").lstrip("v")

if getattr(sys, 'frozen', False):
    if sys.platform == 'darwin':
        sys.stdout = open(os.devnull, 'w')
        sys.stderr = open(os.devnull, 'w')
    template_folder = os.path.join(sys._MEIPASS, 'templates')
    static_folder = os.path.join(sys._MEIPASS, 'static')
    app = Flask(__name__, template_folder=template_folder, static_folder=static_folder)
else:
    app = Flask(__name__)

# Store current state

def get_msg(key, lang):
    msgs = {
        "path_not_exist": {"vi": "Đường dẫn không tồn tại", "en": "Path does not exist"},
        "no_permission": {"vi": "Không có quyền truy cập", "en": "Permission denied"},
        "folder_not_exist": {"vi": "Thư mục không tồn tại", "en": "Folder does not exist"},
        "no_files": {"vi": "Không có file để đổi tên", "en": "No files to rename"},
        "error_prefix": {"vi": "Lỗi", "en": "Error"},
        "rename_success": {"vi": "Đã đổi tên {success_count}/{count} file thành công!", "en": "Successfully renamed {success_count}/{count} files!"}
    }
    return msgs.get(key, {}).get(lang, msgs.get(key, {}).get("en"))

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
    data = request.get_json() or {}
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
    data = request.get_json() or {}
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
    data = request.get_json()
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
