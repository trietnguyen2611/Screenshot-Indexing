---
name: feature-swarm-playbook
description: >-
  Coordinates multi-agent feature development in Screenshot-Indexing using /swarm or invoke_subagent across backend-core, macos-automation, frontend-ui, and qa-release-verifier. Load when planning or implementing multi-layer features spanning Flask routes, macOS automation, UI/i18n, and tests or packaging.
---

# Feature Swarm Playbook

Use this playbook when building multi-layer features in **Screenshot-Indexing** (for example: macOS auto-capture with timed loops and page-turn automation, custom rename templates, EXIF sorting, or rename Undo/Rollback). It enforces strict single-writer file boundaries so `/swarm` workers (or sequential `invoke_subagent` calls) never conflict.

## Subagent Roster & Single-Writer File Ownership Matrix

Subagent definitions live in `.agents/agents/`:

| Subagent | Primary Ownership (Exclusive Write Scope) | Must NOT Edit |
| :--- | :--- | :--- |
| `backend-core` | `app.py` (Flask routes, `state`, `get_msg(key, lang)`, `sys._MEIPASS` resolution) and data/business modules in `services/` (`services/__init__.py`, `services/config_store.py`, `services/renamer.py`, `services/history.py`) | `templates/*`, `static/*`, `.github/*`, `tests/*`, `services/macos_*.py` |
| `macos-automation` | OS-level macOS modules in `services/` (`services/macos_capture.py`, `services/macos_input.py`, `services/macos_overlay.py`, `services/macos_sound.py`, `services/macos_permissions.py`) | `app.py`, `services/__init__.py`, `templates/*`, `static/*`, `.github/*`, `tests/*` |
| `frontend-ui` | `templates/index.html`, `static/app.js`, `static/style.css` | `app.py`, `services/*`, `.github/*`, `tests/*` |
| `qa-release-verifier` | `tests/`, `.github/workflows/build-and-release.yml`, `requirements.txt` compatibility checks | Any file owned by `backend-core`, `macos-automation`, or `frontend-ui` during `/swarm` verification (operates strictly read-only on those files) |

### Coordination Rule
- **Never allow two workers to edit the same file concurrently.**
- Even inside `services/`, split filenames explicitly: `backend-core` owns `services/config_store.py`, `services/renamer.py`, `services/history.py`, and `services/__init__.py`; `macos-automation` owns `services/macos_*.py` and exposes clean Python functions/classes with type hints and docstrings for `app.py` to import directly (`from services.macos_capture import ...`).

## Choosing `/swarm` vs `invoke_subagent`

- **Use `/swarm`** when a feature requires parallel changes across backend, macOS services, and UI (e.g., auto-capture panel + canvas modal + backend loop + tests). Workers collaborate via the shared board with `@name` handoffs.
- **Use `invoke_subagent`** when a task is confined to one layer (e.g., CSS polish in `frontend-ui`) or strictly sequential small steps.

---

## 3-Phase Feature Workflow

### Phase 1: Lock Contracts & Schemas (Coordinator, Before Parallel Editing)

Before spawning parallel writers, lock every cross-boundary interface in the worker briefs or board specification:

1. **HTTP / JSON API Contract (`/api/*`)**
   - Specify exact route paths, HTTP methods, query/body parameters, and response schemas.
   - Follow the existing `app.py` convention: every JSON error or action result returns `{"ok": True/False, "message": ...}`.
   - Require `lang` (`"en"` | `"vi"`, defaulting to `"en"`) on all user-facing endpoints so `app.py` returns localized messages via `get_msg(key, lang)`.
   - Define exact HTTP status codes or error payload fields (e.g., `missing_permissions` booleans for TCC errors).
2. **Service Interface Contract (`backend-core` <-> `macos-automation`)**
   - Lock Python module names (`services/macos_*.py`), function signatures, parameter units (logical screen points vs physical pixels; seconds clamped to `[1, 10]`), and return dictionaries/dataclasses.
   - Example: `macos-automation` never imports Flask `request`/`jsonify` or mutates `app.py`'s `state`; it raises typed errors or returns plain `dict` payloads that `backend-core` translates through `get_msg(key, lang)`.
3. **Persistent Config Schema**
   - Lock config file path (`~/Library/Application Support/Screenshot Indexing/config.json`) and exact JSON keys (e.g., save folder, capture region `{x, y, width, height}`, `interval_sec`, `page_turn_mode`, `page_turn_key`, `click_point {x, y}`, `sound_enabled`) so `backend-core`, `macos-automation`, and `frontend-ui` agree on field names.
4. **UI & i18n Contract (`backend-core` <-> `frontend-ui`)**
   - Lock DOM element IDs, `API` methods in `static/app.js`, and new `get_msg` / `translations` keys so EN/VI coverage is planned upfront.

---

### Phase 2: Parallel Implementation (Zero File Overlap)

Launch workers simultaneously with explicit scope boundaries and required skills:

1. **`backend-core`**
   - Load `universal2-build-verify` (when touching frozen paths/assets) and follow `app.py` patterns.
   - Implement data/config/rename/history services in `services/`.
   - Wire all `/api/*` routes in `app.py`, preserving:
     - Frozen PyInstaller path detection (`getattr(sys, 'frozen', False)`, `sys._MEIPASS`).
     - `is_screenshot_file` NFC/NFD Unicode normalization (`unicodedata.normalize`).
     - Two-step temp-file batch rename (`__temp_rename_`) to prevent overwrite collisions.
   - Add both `"en"` and `"vi"` entries in `get_msg(key, lang)` for every new backend message.

2. **`macos-automation`**
   - Load `.agents/skills/macos-capture-automation/SKILL.md` before coding.
   - Implement pure Python macOS modules in `services/macos_*.py`:
     - Fixed-region capture (`screencapture -x -R x,y,w,h` or Quartz) into the user-configured directory.
     - Non-blocking `Grab.aif` shutter sound (`afplay` via `subprocess.Popen` or `AppKit.NSSound`).
     - Thread-safe `1–10s` capture loop using `threading.Event.wait(timeout)` for instant abort.
     - Both page-turn modes (keyboard keyCode via Quartz/osascript AND fixed `(click_x, click_y)` mouse click via Quartz).
     - Both selection backends (Mode 1 native screen overlay/picker AND Mode 2 full-screen preview + HiDPI metadata).
     - TCC checks (`CGPreflightScreenCaptureAccess`, `AXIsProcessTrusted`).
   - Do **not** edit `app.py` directly; post exact exported signatures on the board if anything extends Phase 1.

3. **`frontend-ui`**
   - Load `.agents/skills/apple-ui-i18n/SKILL.md` before editing UI files.
   - Edit `templates/index.html`, `static/style.css`, and `static/app.js`:
     - Use existing Apple Design System tokens (`--color-*`, `--rounded-*`, `--space-*`, `--font-*`) and provide `[data-theme="dark"]` parity.
     - Reuse `.split-container`, `.sidebar-panel`, `.content-panel`, `.section`, `.card`, `.btn`, `.modal-overlay`, `closeModalWithAnimation()`, `showToast()`, `escapeAttr()`.
     - Add `data-i18n` / `data-i18n-placeholder` / `data-i18n-title` attributes and matching keys in BOTH `translations.en` and `translations.vi`.
     - Pass `lang: currentLang` on all `fetch('/api/...')` calls.

---

### Phase 3: Cross-Verification & Fix Loop (`qa-release-verifier`)

Once Phase 2 workers post their results (and note any new dependencies or bundle requirements), `qa-release-verifier` executes read-only verification on app code and write-enabled verification in `tests/` and build/release verification:

1. **Load Skill**: `.agents/skills/universal2-build-verify/SKILL.md`.
2. **Backend & Automation Tests (`tests/`)**:
   - Run `pytest` covering Flask endpoints via `app.test_client()`, rename collision & NFC/NFD edge cases, timer interval `[1, 10]` clamping, Retina HiDPI pixel-to-point conversion math, and mocked/platform-safe macOS service tests.
3. **EN/VI i18n & UI Parity Audit**:
   - Verify every `data-i18n*` attribute in `templates/index.html` and every `t(...)` call in `static/app.js` has matching keys in both `translations.en` and `translations.vi`.
   - Verify every `get_msg(...)` key in `app.py` defines both `"en"` and `"vi"`.
   - Confirm Light and Dark (`[data-theme="dark"]`) styles exist for any new UI components.
4. **Apple Silicon (`arm64`) Packaging & Dependency Audit**:
   - Check `requirements.txt`, PyInstaller `--add-data` (`templates:templates`, `static:static`, `services:services`) / `--hidden-import` (`Quartz`, `AppKit`) / `--target-arch arm64` flags in `.github/workflows/build-and-release.yml`, `sys._MEIPASS` safety, `-macOS-arm64.dmg` output, and `Info.plist` `plutil` keys (`NSScreenCaptureUsageDescription`, `NSAppleEventsUsageDescription`) injected before `xattr -cr` and `codesign`.
5. **Defect Routing**:
   - Never directly patch files owned by `backend-core`, `macos-automation`, or `frontend-ui` while acting as Verifier.
   - Post exact file paths, failing checks/tracebacks, and `@<owner-worker>` on the board so the owning worker fixes its file, then re-run verification until 100% clean.
