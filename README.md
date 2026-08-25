# Screenshot Indexing

[![Build & Release macOS App](https://github.com/trietnguyen2611/Screenshot-Indexing/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/trietnguyen2611/Screenshot-Indexing/actions/workflows/build-and-release.yml)

An app that helps you sort and rename many screenshot files by time. It follows the **Apple Design System** style.

---

## Main Features

- **Auto Sort**: Sort screenshot files by the exact time they were taken.
- **Custom Numbers**: Enter a start number and end number to rename many files at once.
- **Visual Preview**: See the new names and images before you change anything.
- **Avoid Name Conflicts**: Uses temporary files so data is not overwritten.
- **Folder Browser**: Paste a path or choose a folder directly.

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

## Build the App (macOS App)

```bash
pyinstaller --noconsole --name "Screenshot Indexing" --icon app_icon.icns --add-data "templates:templates" --add-data "static:static" --noconfirm app.py
```

---

## Project Structure

```
Screenshot-Indexing/
├── .github/workflows/   # CI/CD for auto build & release (Intel & Apple Silicon)
├── app.py               # Flask backend & PyWebView
├── app_icon.icns        # App icon
├── requirements.txt     # List of libraries
├── templates/           # HTML interface
└── static/              # CSS & JS frontend
```
