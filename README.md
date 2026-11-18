# Screenshot Indexing — Native macOS SwiftUI (Apple Silicon)

[![Build & Release macOS App](https://github.com/trietnguyen2611/Screenshot-Indexing/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/trietnguyen2611/Screenshot-Indexing/actions/workflows/build-and-release.yml)

A native **macOS 27 SwiftUI Liquid Glass** application built exclusively for **Apple Silicon (`arm64`)** to chronologically index screenshots, batch-rename files safely, summarize screenshot text on-device with Apple Foundation Models, and automate timed screen region capture with auto page-turning.

---

## Requirements

- **Apple Silicon Mac** (`arm64`)
- **macOS 26.0 / macOS 27** (Tahoe Liquid Glass SDK)
- **Swift 6.2+** (for building and testing from source)
- **Apple Intelligence** enabled in System Settings (optional, for on-device AI summarization)

---

## Main Features

- **Chronological Screenshot Indexing** — Scans folders for macOS screenshots in English (`Screenshot ...`) and Vietnamese (`Ảnh màn hình ...` / `anh man hinh ...`, supporting both NFC and NFD Unicode normalization) and sorts them strictly by capture timestamp.
- **Safe Two-Step Batch Rename** — Set custom `From` and `To` numbering ranges, preview mapped filenames (`1.png`, `2.png`, ...), inspect screenshots in a full-resolution preview sheet with keyboard navigation, and apply collision-safe temporary renames that never overwrite existing files.
- **Notes & On-Device Apple Foundation Models AI Summarization** — Persistent auto-saved Notes panel paired with Apple `Vision` OCR and streaming on-device `FoundationModels` summarization (for individual images or an entire indexed batch) with zero cloud uploads.
- **Auto Capture with Liquid Glass Overlay Picker** — Capture fixed logical screen regions on an interval timer with Retina HiDPI coordinate mapping, an interactive screen preview drag canvas, customizable global hotkey (`⌃⇧R` by default), and a full-screen Liquid Glass region picker overlay.
- **Automated Page-Turn & Shutter Audio** — Automatically turn pages between shots via synthesized keyboard shortcuts (customizable key recorder) or mouse clicks, with optional macOS system shutter sound.
- **Bilingual & Adaptive Liquid Glass UI** — Instant English / Vietnamese (`EN` / `VI`) localization and System / Light / Dark appearance switching with macOS Liquid Glass surfaces.

---

## Build, Test & Run from Source

```bash
# Build debug target
swift build

# Run unit tests
swift test

# Run the native app directly
swift run ScreenshotIndexing
```

---

## Build `.app` Bundle & `.dmg` Package

Use the packaging script to compile a release Apple Silicon (`arm64`) binary, generate `Info.plist`, embed `macapp_icon.icns`, strip quarantine attributes, and apply an ad-hoc code signature:

```bash
APP_VERSION=2.0.0 bash scripts/build_app.sh
```

This creates `dist/Screenshot Indexing.app`. You can verify the architecture and signature, then optionally wrap it into a distributable `.dmg`:

```bash
lipo -archs "dist/Screenshot Indexing.app/Contents/MacOS/Screenshot Indexing"
codesign --verify --deep --strict "dist/Screenshot Indexing.app"

mkdir -p release dmg_root
cp -R "dist/Screenshot Indexing.app" dmg_root/
ln -s /Applications dmg_root/Applications
hdiutil create -volname "Screenshot Indexing" -srcfolder dmg_root -ov -format UDZO "release/Screenshot-Indexing-v2.0.0-macOS-arm64.dmg"
rm -rf dmg_root
```

---

## Project Structure

```
Screenshot-Indexing/
├── Package.swift                                  # Swift Package Manager manifest (macOS arm64)
├── Sources/ScreenshotIndexing/
│   ├── ScreenshotIndexingApp.swift                # @main SwiftUI App & window lifecycle
│   ├── Models/
│   │   ├── AppConfig.swift                        # Persistent config model & atomic ConfigStore
│   │   ├── Localization.swift                     # EN / VI localization keys & strings
│   │   └── ScreenshotFile.swift                   # Screenshot item model
│   ├── Services/
│   │   ├── AFMSummarizerService.swift             # Vision OCR + Apple Foundation Models streaming
│   │   ├── FileIndexingService.swift              # NFC/NFD scanning, sorting & 2-step safe rename
│   │   ├── GlobalHotkeyService.swift              # Global & local hotkey monitor
│   │   ├── InputSimulationService.swift           # CGEvent key/click simulation & window PID matching
│   │   ├── PermissionsService.swift               # Screen Recording & Accessibility TCC checks
│   │   ├── ScreenCaptureService.swift             # Screencapture / Quartz capture & timer controller
│   │   └── ScreenOverlayPickerWindow.swift        # Native Liquid Glass full-screen region picker
│   └── Views/
│       ├── LiquidGlassTheme.swift                 # Liquid Glass backdrop, cards, pills & AppViewModel
│       ├── MainContentView.swift                  # Floating glass pill toolbar & tab router
│       ├── IndexingTabView.swift                  # Folder browser, numbering range, notes & file list
│       ├── ImagePreviewSheetView.swift            # Full-size screenshot modal, AI popup & rename confirm
│       ├── AutoCaptureTabView.swift               # Auto-capture controls, hotkey/key recorders & preview
│       └── SettingsTabView.swift                  # AFM availability status, feature toggles & theme
├── Tests/ScreenshotIndexingTests/
│   └── ScreenshotIndexingTests.swift              # Swift unit tests
├── scripts/
│   └── build_app.sh                               # Release arm64 .app bundler & ad-hoc signer
├── .github/workflows/
│   └── build-and-release.yml                      # GitHub Actions CI/CD (test, build arm64 .app, DMG, release)
└── macapp_icon.icns                               # macOS application icon
```

---

## macOS Permissions & Troubleshooting

- **Permissions**: Auto Capture and Screen Preview require **Screen Recording** permission. Automated page-turning and global hotkey capture when another app is focused require **Accessibility** permission (`System Settings -> Privacy & Security`).
- **Gatekeeper ("App is damaged" on unsigned `.dmg` downloads)**:
  1. Drag `Screenshot Indexing.app` from the `.dmg` into **Applications**.
  2. Open **Terminal** and run:
     ```bash
     xattr -cr "/Applications/Screenshot Indexing.app"
     ```
  3. Launch the app normally.
