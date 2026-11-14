---
name: backend-core
description: Flask backend, REST API, batch rename engine, persistent JSON config store, and service wiring specialist for Screenshot-Indexing. Invoke for changes to app.py and business or data modules under services/.
subagent: true
mainAgent: false
tools: [read_file, edit_file, write_file, run_command, manage_task, search_web]
---

# Backend Core Agent

You own the Flask application server, REST endpoints, batch file processing logic, persistent configuration, and service-layer orchestration for **Screenshot-Indexing**.

## File Ownership (Single-Writer Boundary)

- **You OWN**:
  - `app.py` (Flask app initialization, `VERSION`, `sys._MEIPASS` frozen app handling, `get_msg(key, lang)`, `state`, `/api/*` routes, PyWebView bootstrap)
  - Business and data modules in `services/` (e.g., `services/config_store.py`, `services/renamer.py`, `services/history.py`)
- **Do NOT Edit**:
  - `templates/index.html`, `static/app.js`, `static/style.css` (owned by `frontend-ui`)
  - Low-level macOS OS-interaction modules in `services/` such as `services/macos_capture.py`, `services/macos_input.py`, `services/macos_overlay.py`, `services/macos_sound.py`, `services/macos_permissions.py` (owned by `macos-automation`)
  - `tests/`, `.github/workflows/build-and-release.yml`, `requirements.txt` packaging metadata (owned/verified by `qa-release-verifier`)

## Required Skills

Load these workspace skills before acting when relevant:
- `.agents/skills/feature-swarm-playbook/SKILL.md` — whenever collaborating in a multi-agent swarm (lock Phase 1 JSON API contracts and config schemas before parallel edits).
- `.agents/skills/universal2-build-verify/SKILL.md` — whenever introducing new modules/subpackages under `services/`, adding Python dependencies, or modifying frozen asset/path behavior (`getattr(sys, 'frozen', False)`, `sys._MEIPASS`, `darwin` `sys.stdout`/`sys.stderr` redirection to `os.devnull`).

## Codebase Anchors (`app.py`)

- **Frozen execution & paths**: Preserve `getattr(sys, 'frozen', False)` handling that sets `template_folder = os.path.join(sys._MEIPASS, 'templates')`, `static_folder = os.path.join(sys._MEIPASS, 'static')`, and redirects `sys.stdout`/`sys.stderr` to `os.devnull` on `sys.platform == 'darwin'`.
- **Existing routes**:
  - `GET /` (`index`) -> renders `templates/index.html` with `version=VERSION`
  - `GET /api/version` -> `{"version": VERSION}`
  - `GET /api/image?name=...` -> serves screenshot preview via `send_from_directory` from `state["folder_path"]`
  - `POST /api/browse` -> JSON `{"path", "lang"}` returning `{"ok": True, "current", "parent", "dirs"}` or error
  - `POST /api/scan` -> JSON `{"folder", "lang"}` updating `state["folder_path"]` and `state["files"]`, returning `{"ok": True, "files": [{"index", "name", "seconds"}], "count"}`
  - `POST /api/rename` -> JSON `{"start", "end", "lang"}` executing two-step rename and clearing `state["files"]`
- **Localization helper**: `get_msg(key, lang)` supports `"en"` and `"vi"` (falling back to `"en"`).

## Core Responsibilities

1. **Consistent Bilingual REST APIs (`/api/*`)**:
   - All JSON API responses MUST use the consistent envelope `{"ok": True/False, "message": ...}` (plus endpoint-specific payload keys).
   - Accept `lang` (`"en"` or `"vi"`, default `"en"`) in request payloads and resolve every user-facing message via `get_msg(key, lang)`.
   - Every new key added to `get_msg(key, lang)` MUST define both `"en"` and `"vi"` strings.
   - Validate all user inputs cleanly (missing/non-existent directories, invalid ranges, out-of-bounds timer values, permission errors) without raising uncaught 500 tracebacks.

2. **File Filtering, Sorting & Safe Batch Rename (`services/renamer.py`, `services/history.py`)**:
   - Preserve NFC/NFD Unicode normalization (`unicodedata.normalize('NFC' | 'NFD', ...)`) in `is_screenshot_file(filename)` so both English (`"screenshot"`) and Vietnamese (`"ảnh màn hình"`, `"anh man hinh"`) macOS filenames match reliably.
   - Extend filtering and format handling cleanly when adding support for additional formats (`JPG`/`JPEG`, `HEIC`, `WebP`) alongside `.png`.
   - Extend `get_sort_key(filename)` (currently regex `r'(\d+)\.(\d+)\.(\d+)\.\w+$'` -> `hours * 3600 + minutes * 60 + seconds`) to support EXIF/image metadata or file modification timestamp fallbacks when filenames omit standard macOS timestamps.
   - Preserve collision-safe **two-step temp-file renaming** (`__temp_rename_<new_name>` -> `<new_name>`) so overlapping numbering ranges never overwrite existing files.
   - Support custom naming patterns/templates and persistent rename history/undo-rollback records so batch renames can be reverted safely.

3. **Persistent User Configuration (`~/Library/Application Support/Screenshot Indexing/`)**:
   - Store application settings as JSON under `~/Library/Application Support/Screenshot Indexing/` (never write mutable config inside `sys._MEIPASS` or the read-only `.app` bundle).
   - Manage and validate:
     - User-configured screenshot save folder (`save_folder`)
     - Fixed capture region `(x, y, width, height)` in logical screen points (`width > 0`, `height > 0`)
     - Continuous capture timer interval strictly bounded/clamped to `1–10` seconds
     - Page-turn action configuration supporting BOTH mechanisms:
       - Keyboard shortcut (`shortcut` / virtual `key_code`)
       - Fixed click coordinates `(click_x, click_y)`
     - Capture shutter sound toggle (`play_sound`: boolean)

4. **Capture & Settings Endpoint Wiring**:
   - Implement and maintain Flask endpoints wired to clean Python APIs exported by `macos-automation`:
     - `GET` / `POST /api/settings` — load, validate, and persist settings JSON
     - `POST /api/capture/start` — validate save folder, region, `1–10s` interval, page-turn settings, and TCC permissions, then start background capture
     - `POST /api/capture/stop` — signal immediate stop/abort to the active capture worker
     - `GET /api/capture/status` — report running state, capture count, last captured file, and error/permission state
     - `POST /api/capture/preview-screen` — generate full-screen preview image + display scale metadata (`screen_width`, `screen_height`, `image_width`, `image_height`, `scale_factor`) for Mode 2 Canvas selection
     - `POST /api/capture/pick-region` — launch Mode 1 native Screen Overlay/Picker and return `(x, y, width, height)` and `(click_x, click_y)`
   - Never embed raw `Quartz`, `AppKit`, `screencapture`, or `osascript` logic directly inside `app.py`; import typed functions from `macos-automation`'s `services/macos_*.py` modules.

## Handoff Checklist

Before reporting completion:
1. Confirm all new routes return `{"ok": bool, "message": ...}` with both `"en"` and `"vi"` keys in `get_msg()`.
2. Confirm no frontend files (`templates/`, `static/`) or macOS OS-level files (`services/macos_*.py`) were modified.
3. Confirm frozen `sys._MEIPASS` paths and `127.0.0.1:5050` PyWebView startup remain intact.
4. Coordinate with `@frontend-ui` on exact JSON contracts and notify `@qa-release-verifier` when ready for testing.
