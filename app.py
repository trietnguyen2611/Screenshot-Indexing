import os
import re
import json
from flask import Flask, render_template, jsonify, request

app = Flask(__name__)

# Store current state
state = {
    "folder_path": "",
    "files": []
}


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
    return render_template("index.html")


@app.route("/api/browse", methods=["POST"])
def browse_directory():
    """List subdirectories at a given path for the web-based folder browser."""
    data = request.get_json() or {}
    path = data.get("path", os.path.expanduser("~"))

    if not os.path.isdir(path):
        return jsonify({"ok": False, "message": "Đường dẫn không tồn tại"})

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
        return jsonify({"ok": False, "message": "Không có quyền truy cập"})


@app.route("/api/scan", methods=["POST"])
def scan_files():
    """Scan folder for screenshot files."""
    data = request.get_json() or {}
    folder = data.get("folder", state["folder_path"])

    if not folder or not os.path.isdir(folder):
        return jsonify({"ok": False, "message": "Thư mục không tồn tại"})

    state["folder_path"] = folder

    files = [
        f for f in os.listdir(folder)
        if f.lower().startswith("screenshot") and f.lower().endswith(".png")
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
        return jsonify({"ok": False, "message": "Không có file để đổi tên"})

    if not folder or not os.path.isdir(folder):
        return jsonify({"ok": False, "message": "Thư mục không tồn tại"})

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
        return jsonify({"ok": False, "message": f"Lỗi: {str(e)}"})

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
        "message": f"Đã đổi tên {success_count}/{count} file thành công!"
    })


if __name__ == "__main__":
    import webbrowser
    print("\n  Screenshot Index")
    print("  ─────────────────────────────")
    print("  Mở trình duyệt: http://localhost:5050")
    print("  Nhấn Ctrl+C để tắt\n")
    webbrowser.open("http://localhost:5050")
    app.run(host="127.0.0.1", port=5050, debug=False)
