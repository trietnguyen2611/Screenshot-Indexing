# Screenshot Indexing

[![Build & Release macOS App](https://github.com/trietnguyen2611/Screenshot-Indexing/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/trietnguyen2611/Screenshot-Indexing/actions/workflows/build-and-release.yml)

A native **macOS Liquid Glass** utility built for **Apple Silicon (`arm64`)** to organize screenshots chronologically, batch-rename files safely, summarize screenshot content on-device with Apple Intelligence, and automate timed screen region capture with auto page-turning.

---

## Requirements

- **Apple Silicon** (`arm64`)
- **macOS 26.0+** (Liquid Glass UI)
- **Apple Intelligence** enabled in System Settings *(optional, required only for on-device AI summarization)*

---

## Features

### 1. Screenshot Indexing & Safe Batch Rename
- **Automatic Chronological Sorting**: Scans any folder for macOS screenshots in English (`Screenshot ...`) and Vietnamese (`Ảnh màn hình ...` / `anh man hinh ...`, supporting both NFC and NFD Unicode) and orders them strictly by capture timestamp.
- **Numbering Range & Live Preview**: Set custom **From** and **To** numbers and preview every mapped filename (`1.png`, `2.png`, ...) before applying changes.
- **Two-Step Collision-Safe Rename**: Renames files through temporary names first and skips existing targets so existing files are never accidentally overwritten.
- **Full-Resolution Image Preview**: Click any row in the file list to inspect the screenshot at full size and navigate between images using keyboard arrow keys (`←` / `→` / `↑` / `↓`).

### 2. Notes & On-Device AI Summarization (Apple Foundation Models)
- **Persistent Notes Workspace**: Built-in notes panel that saves automatically while you review screenshots.
- **Batch AI Summarize**: Extracts text from indexed screenshots via Apple Vision OCR and streams concise Markdown notes directly into the Notes panel using on-device Apple Foundation Models — **100% offline, no API key or cloud upload required**.
- **Single-Image AI Summary**: Trigger **AI Summarize Image** inside the preview modal to stream a local summary popup over the current screenshot with one-click copy.

### 3. Auto Capture & Screen Region Selection
- **Interactive Screen Preview**: Capture a test screenshot and drag directly on the preview canvas to define or adjust the capture region (`X`, `Y`, `W`, `H` in logical points with Retina HiDPI support).
- **Global Hotkey & Overlay Picker**: Press the customizable global shortcut (`⌃⇧R` by default) from **any** foreground app (such as Safari or a PDF reader) to open the full-screen region picker overlay and automatically update Screen Preview.
- **Timer, Shot Limit & Shutter Sound**: Configure capture interval (`1–10s`), optional shot limit (`0 = ∞`), and optional macOS shutter sound.
- **Automated Page-Turn**: Automatically advance pages between shots using a recorded keyboard shortcut or mouse click.

### 4. Settings & Customization
- **On-Device AI Status**: View live Apple Foundation Model availability and recheck readiness from the **Settings** tab.
- **Feature Toggles**: Individually enable or disable **AI Note Summarization**, the **Notes Panel**, the **Auto Capture Tab**, and **macOS Shutter Sound**.
- **Bilingual & Adaptive Appearance**: Switch instantly between **English (`EN`)** and **Vietnamese (`VI`)**, and choose **System**, **Light**, or **Dark** appearance.

---

## macOS Permissions & Installation

- **Screen Recording**: Required for **Auto Capture** and **Screen Preview**.
- **Accessibility**: Required for **Auto Page-Turn** and the **Global Hotkey** when another app is in focus.
  *(Both can be opened directly from the Permissions section in Auto Capture → `System Settings → Privacy & Security`.)*
- **Opening the downloaded `.dmg` (unsigned ad-hoc build)**:
  1. Drag `Screenshot Indexing.app` into **Applications**.
  2. Run in **Terminal**:
     ```bash
     xattr -cr "/Applications/Screenshot Indexing.app"
     ```
  3. Launch the app normally.

---

## Building from Source (Developers)

Requires **Swift 6.2+** on macOS `arm64`:

```bash
swift test
swift run ScreenshotIndexing
APP_VERSION=2.0.0 bash scripts/build_app.sh
```
