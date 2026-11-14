---
name: universal2-build-verify
description: >-
  Documents frozen PyInstaller execution in app.py, Apple Silicon (arm64) CI build workflow, Info.plist plutil permission keys, Screenshot-Indexing-VERSION-macOS-arm64.dmg packaging, and unittest/pytest/i18n pre-release verification. Load when adding modules or dependencies, changing packaging/CI files, or performing release QA.
---

# Apple Silicon (`arm64`) Build & Release Verification Guide

Use this guide whenever adding Python modules/dependencies, modifying packaging or GitHub Actions workflows, or verifying release readiness for **Screenshot-Indexing** on **macOS Apple Silicon (`arm64`)**.

*(Skill directory/name remains `universal2-build-verify` for backwards reference compatibility while documenting the `arm64`-only Apple Silicon pipeline.)*

---

## 1. Frozen PyInstaller Execution (`app.py`)

`app.py` handles bundled `.app` execution and frozen overlay picker subprocess dispatch:

```python
if "--overlay-picker" in sys.argv:
    idx = sys.argv.index("--overlay-picker")
    target = sys.argv[idx + 1] if idx + 1 < len(sys.argv) else "region"
    from services.macos_overlay import run_overlay_cli
    sys.exit(run_overlay_cli(target))

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
```

### Critical Implications for New Features
1. **Asset path resolution**: Any bundled read-only resource must resolve via `sys._MEIPASS` when `getattr(sys, 'frozen', False)` is `True` (and `os.path.dirname(os.path.abspath(__file__))` when running from source).
2. **Never write user state into `sys._MEIPASS`**: Store persistent config, logs, or temporary preview images inside `~/Library/Application Support/Screenshot Indexing/` or `tempfile.gettempdir()`.
3. **`stdout`/`stderr` are redirected to `os.devnull` on frozen `darwin`**: Do not rely on `print()` for critical runtime diagnostics; surface user-facing errors in JSON API responses (`{"ok": False, "message": ...}`) or optional log files in Application Support.
4. **Subprocess caution when frozen**: In a PyInstaller bundle, `sys.executable` points to `Screenshot Indexing` (the compiled app binary), **not** a standalone `python3` interpreter. Always dispatch helper CLI modes (such as `--overlay-picker`) at the top of `app.py` **before** `os.devnull` redirection so stdout JSON arrives intact.

---

## 2. PyInstaller Flags & Dependency Changes (`arm64`)

### Current Build Command (`.github/workflows/build-and-release.yml`)
```bash
APP_VERSION="${RAW_VER}" python -m PyInstaller \
  --noconsole \
  --name "Screenshot Indexing" \
  --icon macapp_icon.icns \
  --add-data "templates:templates" \
  --add-data "static:static" \
  --add-data "services:services" \
  --hidden-import Quartz \
  --hidden-import AppKit \
  --osx-bundle-identifier "com.trietnguyen2611.screenshotindexing" \
  --target-arch arm64 \
  --noconfirm \
  app.py
```

### Current `requirements.txt`
```text
Flask>=3.0.0
pywebview>=5.0.0
pyinstaller>=6.0.0
```
*(Note: On macOS, `pywebview>=5.0.0` installs `pyobjc-framework-Cocoa` (`AppKit`) and `pyobjc-framework-Quartz` (`Quartz`) automatically.)*

### Checklist When Introducing `services/` or New Dependencies
- **New `services/` modules**:
  - Bundle `services/` via `--add-data "services:services"` alongside static imports in `app.py`.
- **Native PyObjC frameworks (`Quartz`, `AppKit`)**:
  - Include `--hidden-import Quartz` and `--hidden-import AppKit` in the `Build ARM64 App` step of `.github/workflows/build-and-release.yml`.
  - Verify wheels install and import cleanly on native Apple Silicon (`arm64`) Python `3.11.9`.

---

## 3. Apple Silicon (`arm64`) CI Pipeline (`.github/workflows/build-and-release.yml`)

### Build Stages (`build-arm64` on `macos-latest`)
1. **Python Runtime**: Installs `python-3.11.9-macos11.pkg` to `/Library/Frameworks/Python.framework/Versions/3.11/bin/python3.11` and logs `lipo -archs "${PYTHON}"`.
2. **Determine Version**: Resolves version from `inputs.version`, release tag, `refs/tags/v*`, or `VERSION` in `app.py`.
3. **ARM64 Build (`Build ARM64 App`)**: Creates `.venv-arm64`, installs `requirements.txt`, builds directly to `dist/Screenshot Indexing.app` with `--target-arch arm64`, verifies `lipo -archs "dist/Screenshot Indexing.app/Contents/MacOS/Screenshot Indexing"`, and cleans `build/`.

---

## 4. `Info.plist` `plutil` Updates & Codesigning Order

In `.github/workflows/build-and-release.yml` (`Update Info.plist & Codesign` step), update `dist/Screenshot Indexing.app/Contents/Info.plist` **BEFORE** `xattr -cr` and `codesign` (editing `Info.plist` after signing invalidates the bundle signature):

```bash
PLIST_PATH="dist/Screenshot Indexing.app/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$RAW_VER" "$PLIST_PATH"
plutil -replace CFBundleVersion -string "$RAW_VER" "$PLIST_PATH"
plutil -replace CFBundleIdentifier -string "com.trietnguyen2611.screenshotindexing" "$PLIST_PATH"
plutil -replace NSHumanReadableCopyright -string "Copyright © 2026 trietnguyen2611. All rights reserved." "$PLIST_PATH"
plutil -replace NSScreenCaptureUsageDescription -string "Screenshot Indexing needs Screen Recording access to capture your selected screen region and preview full-screen coordinates." "$PLIST_PATH"
plutil -replace NSAppleEventsUsageDescription -string "Screenshot Indexing uses AppleEvents to send automated page-turn shortcuts when capturing pages." "$PLIST_PATH"

xattr -cr "dist/Screenshot Indexing.app"
codesign --force --deep --sign - "dist/Screenshot Indexing.app"
```

---

## 5. Binary Verification, DMG Packaging & Pre-Release QA

### Binary & DMG Checks (from CI Workflow)
1. **Apple Silicon (`arm64`) Verification**:
   ```bash
   MAIN_BIN="dist/Screenshot Indexing.app/Contents/MacOS/Screenshot Indexing"
   lipo -archs "$MAIN_BIN"
   # Output MUST include arm64 and MUST NOT include x86_64
   ```
2. **Code Signature Check**:
   ```bash
   codesign --verify --deep --strict "dist/Screenshot Indexing.app"
   ```
3. **DMG Creation (`-macOS-arm64.dmg`)**:
   ```bash
   VERSION="${{ steps.get_version.outputs.version }}"
   mkdir -p release dmg_root
   cp -R "dist/Screenshot Indexing.app" dmg_root/
   ln -s /Applications dmg_root/Applications
   hdiutil create \
     -volname "Screenshot Indexing" \
     -srcfolder dmg_root \
     -ov -format UDZO \
     "release/Screenshot-Indexing-${VERSION}-macOS-arm64.dmg"
   rm -rf dmg_root
   ```
   Artifact upload name: `Screenshot-Indexing-${{ steps.get_version.outputs.version }}-macOS-arm64`.
   GitHub Release file: `release/Screenshot-Indexing-${{ steps.get_version.outputs.version }}-macOS-arm64.dmg`.

### Pre-Release Test & Verification Checklist
Run before approving any release or PR:
1. **Automated Test Suite**:
   ```bash
   .venv/bin/python3.15 -m unittest discover -s tests -v
   # (Also compatible with `pytest -v` when pytest is installed)
   ```
   Verify coverage of:
   - Existing & new Flask endpoints (`app.test_client()`): `/`, `/api/version`, `/api/browse`, `/api/scan`, `/api/rename`, `/api/image`, `/api/settings`, `/api/capture/*`.
   - `is_screenshot_file` NFC/NFD Vietnamese Unicode normalization (`"ảnh màn hình"`, `"anh man hinh"`, `"screenshot"`).
   - Two-step temp-file rename (`__temp_rename_`) collision prevention and boundary cases.
   - Timer interval clamping `[1, 10]` seconds and Retina HiDPI pixel-to-point coordinate conversions.
2. **EN/VI i18n Parity**: Confirm zero missing keys across `templates/index.html`, `static/app.js`, and `app.py` (`get_msg`).
3. **Frozen Launch Smoke Test** (on Apple Silicon macOS): Build local `--target-arch arm64` `.app` via PyInstaller and confirm it launches without `sys._MEIPASS` template/static errors or `stdout`/`stderr` crashes, and inspect `Contents/Info.plist` via `plutil -p` for bundle ID, version, and TCC keys.
