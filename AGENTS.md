# Screenshot-Indexing — Workspace Rules

## 1. Project Overview

`Screenshot-Indexing` is a macOS desktop app built with **Python 3.11**, **Flask** (`>=3.0.0`), and **PyWebView** (`>=5.0.0`), styled with the Apple Design System (`static/style.css`) and packaged for **macOS Apple Silicon (`arm64`)** as a `.app` and `.dmg` via **PyInstaller** (`>=6.0.0`) and GitHub Actions (`.github/workflows/build-and-release.yml`, bundle ID `com.trietnguyen2611.screenshotindexing`).

- **Current Runtime**: `app.py` serves Flask on `127.0.0.1:5050` inside a `1200x800` PyWebView window (`/` UI, `/api/version`, `/api/image`, `/api/browse`, `/api/scan`, `/api/rename`) to sort screenshots chronologically and batch-rename them safely.
- **Planned Features**: Auto-capture of a fixed screen region on a 1–10s timer with automatic page-turning (keyboard shortcut or fixed click coordinate), dual region/point selection (screen overlay picker + in-app preview Canvas), macOS shutter sound, TCC permission checks, persistent settings, and extended rename/format/undo workflows.

## 2. Subagent Roster & Single-Writer File Ownership Matrix

During `/swarm`, **two workers MUST NEVER edit the same file concurrently**. Route every edit exclusively to its owning subagent:

| Subagent | Definition File | Exclusive Write Ownership | Must Not Edit |
| :--- | :--- | :--- | :--- |
| `backend-core` | `.agents/agents/backend-core.md` | `app.py` (Flask routes, `sys._MEIPASS`, `get_msg`, `state`) & business/data/config/rename/history services in `services/` | `templates/*`, `static/*`, OS-level `services/macos_*.py`, `.github/*` |
| `macos-automation` | `.agents/agents/macos-automation.md` | OS-level macOS services in `services/` (fixed-region capture, 1–10s timer loop, shortcut & `(x, y)` click page-turn, `Grab.aif` sound, overlay picker, Retina HiDPI math, TCC permissions) | `app.py`, `templates/*`, `static/*`, `.github/*` (expose typed Python APIs for `backend-core`) |
| `frontend-ui` | `.agents/agents/frontend-ui.md` | `templates/index.html`, `static/app.js`, `static/style.css` | `app.py`, `services/*`, `tests/*`, `.github/*` |
| `qa-release-verifier` | `.agents/agents/qa-release-verifier.md` | `tests/`, `.github/workflows/build-and-release.yml`, `requirements.txt` verification | **Read-only** on `app.py`, `services/*`, `templates/*`, `static/*` during `/swarm`; report bugs to the owner |

**Coordination Rules**: Lock `/api/*` JSON contracts, `lang` handling, and config schema before parallel coding. `macos-automation` exports pure Python APIs in `services/` that `backend-core` wires into `app.py`. `qa-release-verifier` never edits source files owned by other workers.

## 3. Project Invariants (Must Always Hold)

- **Safe Batch File Operations & Unicode**: Preserve two-step temp-file renaming (`__temp_rename_<new_name>` + `os.path.exists` collision guard before final `os.rename`) and `unicodedata.normalize('NFC'|'NFD', ...)` checks in `is_screenshot_file()` for English/Vietnamese macOS prefixes (`"screenshot"`, `"ảnh màn hình"`, `"anh man hinh"`). Keep `get_sort_key()` / EXIF chronological sorting deterministic.
- **Consistent Flask JSON API**: Return `{"ok": bool, "message": ...}` (plus route-specific payload on success) across `/api/*` endpoints, passing `lang` (`"en"` / `"vi"`, default `"en"`) through `get_msg(key, lang)` in `app.py`.
- **Mandatory EN/VI i18n Parity**: Keep 100% English/Vietnamese parity across `templates/index.html` (`data-i18n`, `data-i18n-placeholder`, `data-i18n-title`), `static/app.js` (`translations.en`, `translations.vi`, `t(key, vars)`), and `app.py` (`get_msg(key, lang)`). Avoid new hardcoded single-language strings in UI, toasts, status text, or API errors.
- **Apple Design System & Light/Dark Themes**: Use `static/style.css` tokens (`--color-*`, `--rounded-*`, `--space-*`, `--font-*` including `--font-display` and `--font-body`) and support both `:root` (Light) and `[data-theme="dark"]` (Dark) on all components. Reuse `closeModalWithAnimation()`, `showToast()`, `setStatus()`, and `escapeAttr()`.
- **macOS Auto-Capture & Automation Standards**:
  - **Save Directory**: User-configurable save folder persisted in `~/Library/Application Support/Screenshot Indexing/` (never hardcoded).
  - **Fixed Region & Retina HiDPI**: Capture fixed bounding box `(x, y, w, h)` accurately across Retina scaling (`scale_factor = image_width / screen_width`), converting between physical PNG pixels (in-app Canvas) and logical screen points (`screencapture -R x,y,w,h` and Quartz `CGEvent`).
  - **1–10s Non-Blocking Timer**: Clamp interval strictly to `1–10s`. Run capture loops in a background thread using `threading.Event` for immediate clean Stop/abort and mutual exclusion against overlapping runs.
  - **Dual Page-Turn Triggers**: Support both (a) keyboard shortcut (`Right: 124`, `Left: 123`, `Down: 125`, `Up: 126`, `Space: 49`, `PageDown: 121`, `Return: 36`, or custom key via `Quartz.CGEventCreateKeyboardEvent` / `osascript`) and (b) fixed click at `(click_x, click_y)` via `Quartz.CGEventCreateMouseEvent`.
  - **Dual Selection Modes**: Support both (a) screen Overlay/Picker returning logical `(x, y, w, h)` and `(click_x, click_y)`, and (b) in-app full-screen preview Canvas using `{screen_width, screen_height, image_width, image_height, scale_factor}` metadata.
  - **Shutter Sound & TCC Permissions**: Play `/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Grab.aif` non-blocking (`subprocess.Popen(["afplay", ...])` or `AppKit.NSSound`) without stalling the timer. Preflight `Screen Recording` (`CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess`) and `Accessibility` (`AXIsProcessTrusted`) with clear user guidance.
- **Packaging & Release Safety**: Preserve `getattr(sys, 'frozen', False)`, `sys._MEIPASS` resolution for `templates` and `static`, and `darwin` `os.devnull` redirection in `app.py`. When adding modules (`services/`) or dependencies, keep `requirements.txt`, PyInstaller `--add-data`/`--hidden-import` flags (`--target-arch arm64` in `.github/workflows/build-and-release.yml`), and `Info.plist` permission keys (`NSScreenCaptureUsageDescription`, `NSAppleEventsUsageDescription`) aligned for Apple Silicon (`arm64`) `.app`/`.dmg` packaging.

## 4. Workspace Skills Guide

| Skill Path | When to Load |
| :--- | :--- |
| `.agents/skills/feature-swarm-playbook/SKILL.md` | Coordinating or implementing multi-layer features via `/swarm` or subagents (API lock, ownership matrix, 3-phase flow). |
| `.agents/skills/macos-capture-automation/SKILL.md` | Implementing macOS capture, Retina HiDPI math, 1–10s `threading.Event` loop, shortcut/click page-turn, `Grab.aif` sound, overlay/Canvas selection, or TCC checks. |
| `.agents/skills/apple-ui-i18n/SKILL.md` | Editing `templates/index.html`, `static/app.js`, or `static/style.css` (Apple Design System Light/Dark tokens, modal/table patterns, EN/VI parity). |
| `.agents/skills/universal2-build-verify/SKILL.md` | Updating `requirements.txt`, `sys._MEIPASS` bundling, `tests/`, `Info.plist` keys, PyInstaller `--target-arch arm64` flags, or Apple Silicon (`arm64`) CI/DMG build & release scripts. |
