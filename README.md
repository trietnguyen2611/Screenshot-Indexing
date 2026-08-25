# Screenshot Indexing – Batch Rename & Sort Screenshots by Time

[![Build & Release macOS App](https://github.com/trietnguyen2611/Screenshot-Indexing/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/trietnguyen2611/Screenshot-Indexing/actions/workflows/build-and-release.yml)

A simple **screenshot indexing and batch rename tool** for macOS. Automatically sort screenshots by capture time and rename them with custom numbers. Designed with Apple Design System principles.

Ideal for people who take many screenshots and want clean, ordered file names.

---

## Main Features

- **Auto Sort by Time** — Arrange screenshot files by the exact time they were taken.
- **Custom Number Range** — Set start and end numbers to rename many files at once.
- **Live Preview** — See new file names and images before applying any change.
- **Safe Rename** — Uses temporary files to avoid overwriting or losing data.
- **Easy Folder Selection** — Paste a path or browse folders directly.

---

## Install & Run from Source

```bash
# 1. Create virtual environment and install libraries
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 2. Run the app
python app.py
```

---

## Build macOS App

```bash
pyinstaller --noconsole --name "Screenshot Indexing" --icon macapp_icon.icns --add-data "templates:templates" --add-data "static:static" --noconfirm app.py
```

---

## Project Structure

```
Screenshot-Indexing/
├── .github/workflows/   # CI/CD auto build & release (Universal for Intel & Apple Silicon)
├── app.py               # Flask backend + PyWebView
├── macapp_icon.icns     # App icon
├── requirements.txt     # Python dependencies
├── templates/           # HTML interface
└── static/              # CSS and JavaScript
```

---

## macOS Troubleshooting (App is damaged)

When downloading the `.dmg` from GitHub Releases, macOS Gatekeeper might block the application with this error: **"Screenshot Indexing is damaged and can't be opened. You should move it to the Trash."**

**How to fix:**
1. Drag and drop the `Screenshot Indexing.app` from the DMG into your **Applications** folder.
2. Open the **Terminal** app.
3. Run this command to remove the quarantine attribute:
   ```bash
   xattr -cr "/Applications/Screenshot Indexing.app"
   ```
4. Open the app normally.

---

## Keywords

`screenshot indexing` `batch rename screenshots` `macOS screenshot tool` `rename files by time` `Python Flask PyWebView` `Apple Design` `screenshot organizer`
