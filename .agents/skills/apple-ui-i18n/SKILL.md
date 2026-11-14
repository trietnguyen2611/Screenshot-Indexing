---
name: apple-ui-i18n
description: >-
  Apple Design System CSS tokens, light and dark theme overrides, layout and modal patterns, and mandatory EN/VI bilingual i18n workflow for Screenshot-Indexing. Load before editing templates/index.html, static/style.css, static/app.js, or bilingual backend messages in app.py.
---

# Apple Design System & EN/VI i18n Guide

Follow these exact tokens, UI patterns, and bilingual requirements whenever modifying `templates/index.html`, `static/style.css`, `static/app.js`, or localized messages in `app.py`.

---

## 1. Apple Design System Tokens (`static/style.css`)

Always style new components using CSS custom properties from `static/style.css` rather than inventing new color palettes.

### Light Theme Tokens (`:root`, lines 4–51)
| Category | Custom Property | Value |
| :--- | :--- | :--- |
| Brand & Accent | `--color-primary` | `#0066cc` |
| Brand & Accent | `--color-primary-focus` | `#0071e3` |
| Brand & Accent | `--color-primary-on-dark` | `#2997ff` |
| Text | `--color-ink` | `#1d1d1f` |
| Text | `--color-ink-muted-80` | `#333333` |
| Text | `--color-ink-muted-48` | `#7a7a7a` |
| Surfaces | `--color-canvas` | `#ffffff` |
| Surfaces | `--color-canvas-parchment` | `#f5f5f7` |
| Surfaces | `--color-surface-pearl` | `#fafafc` |
| Borders | `--color-hairline` | `#e0e0e0` |
| Borders | `--color-divider-soft` | `#f0f0f0` |
| On surfaces | `--color-on-primary` | `#ffffff` |
| Semantic | `--color-success` | `#34c759` |
| Semantic | `--color-warning` | `#ff9500` |
| Semantic | `--color-error` | `#ff3b30` |
| Rounded | `--rounded-xs` / `--rounded-sm` / `--rounded-md` / `--rounded-lg` / `--rounded-pill` | `5px` / `8px` / `11px` / `18px` / `9999px` |
| Spacing | `--space-xxs` / `--space-xs` / `--space-sm` / `--space-md` / `--space-lg` / `--space-xl` / `--space-xxl` | `4px` / `8px` / `12px` / `17px` / `24px` / `32px` / `48px` |
| Typography | `--font-display` | `"SF Pro Display", system-ui, -apple-system, "Helvetica Neue", Arial, sans-serif` |
| Typography | `--font-body` | `"SF Pro Text", system-ui, -apple-system, "Helvetica Neue", Arial, sans-serif` |

### Dark Theme Overrides (`[data-theme="dark"]`, lines 1252–1269)
| Custom Property | Dark Value |
| :--- | :--- |
| `--color-primary` | `#0a84ff` |
| `--color-primary-focus` | `#409cff` |
| `--color-primary-on-dark` | `#2997ff` |
| `--color-ink` | `#f5f5f7` |
| `--color-ink-muted-80` | `#e5e5ea` |
| `--color-ink-muted-48` | `#98989d` |
| `--color-canvas` | `#1c1c1e` |
| `--color-canvas-parchment` | `#2c2c2e` |
| `--color-surface-pearl` | `#3a3a3c` |
| `--color-hairline` | `#38383a` |
| `--color-divider-soft` | `#2c2c2e` |
| `--color-on-primary` | `#ffffff` |

### Dark Mode Checklist for New CSS
- `static/style.css` includes explicit `[data-theme="dark"]` overrides for `body` (`#121214`), `.header` (`rgba(28, 28, 30, 0.82)`), `.card`, `.modal`, `.toast` (`#252528`), `.folder-input-wrapper`, `.range-input`, `thead th`, `tbody td`, `.image-body`, and `.image-nav-btn`.
- For any **new** component:
  - Prefer `var(--color-*)` for backgrounds, text, and borders so Light/Dark mode switches automatically.
  - Add `[data-theme="dark"]` rules whenever using custom shadows, `rgba(...)` focus rings (light: `0 0 0 3px rgba(0, 102, 204, 0.15)`, dark: `0 0 0 3px rgba(10, 132, 255, 0.25)`), or translucent surfaces.
- Theme state is managed in `static/app.js` by `initTheme()` / `toggleTheme()` (`localStorage` key `'user_theme'` and `<html data-theme="...">`).

---

## 2. Layout, Component & JS Helper Patterns

### Existing Layout Skeleton (`templates/index.html`)
- **Top bar**: `<header class="header">` with `.header-brand`, `.header-title`, `.app-version-badge`.
- **Workspace**: `<main class="main">` -> `.split-container#split-container`:
  - `.sidebar-panel#sidebar-panel` (resizable width `290px`–`650px`, `overflow-y: auto`)
    - `.section` blocks: `.section-header` (`.section-icon`, `.section-title`, optional `.section-badge`) + `.card`
    - `.sidebar-prefs` pinned at the bottom (`margin-top: auto`) holding `#lang-select.lang-select`
  - `.resizer-handle#resizer-handle` (`initResizer()`, persists `'sidebar_width'` in `localStorage`)
  - `.content-panel#content-panel` (`min-width: 320px`, holds `.section.section-file-list`, `#table-wrapper`, `#empty-state`)

### Buttons & Reusable Classes (`static/style.css`)
- `.btn` + `.btn-primary` (filled blue), `.btn-secondary` (pearl surface), `.btn-utility` (modal footer/nav pearl surface), `.btn-floating` (glass FAB), `.btn-icon`, `.spinner`.

### Modals (`static/app.js` + `static/style.css`)
- Structure: `<div id="..." class="modal-overlay" style="display: none;" onclick="...Outside(event)">` wrapping `<div class="modal">` with `.modal-header` (`.modal-title` + `.modal-close`), body, and `.modal-footer`.
- Opening:
  ```javascript
  modal.classList.remove('closing');
  modal.style.display = 'flex';
  ```
- Closing: **always** use `closeModalWithAnimation(modal, callback)` (`190ms` `.closing` animation), and register new modals inside the global `Escape` `keydown` handler in `static/app.js`.

### Notifications, Status & Escaping (`static/app.js`)
- `showToast(message, typeOrDuration = 'info', duration = 3000)`:
  - Types: `'info'`, `'success'`, `'warning'`, `'error'`.
  - **Security note**: `showToast` interpolates `message` into `toast.innerHTML`. Always call `escapeAttr(...)` before passing untrusted filenames, OS paths, or raw error strings into `showToast`.
- `setStatus(text, type = '')`:
  - Updates `#status-text` and `#status-dot` if present in the DOM (currently guarded with null checks because neither element exists in `templates/index.html`).
- `escapeAttr(str)`:
  - Escapes `&`, `"`, `'`, `<`, `>` before inserting dynamic filenames or paths into HTML templates/attributes.

---

## 3. Mandatory Bilingual EN/VI (`en` / `vi`) Workflow

Every user-facing string MUST exist in both **English (`en`)** and **Vietnamese (`vi`)**.

1. **Static HTML (`templates/index.html`)**
   - Use `data-i18n="<key>"` for text content, `data-i18n-placeholder="<key>"` for input placeholders, and `data-i18n-title="<key>"` for tooltips.
   - Always place `data-i18n` on an inner `<span>` rather than a button/header that also contains `<svg>` icons, because `updateDOMTranslations()` assigns `el.textContent` and would wipe sibling SVG nodes.
2. **Frontend JS (`static/app.js`)**
   - Add matching keys to **both** `translations.en` and `translations.vi`.
   - Use `t('key', { var: val })` for all dynamic toasts, labels, and confirmations. Note: `t()` uses single-pass `.replace(\`{\${k}}\`, v)`.
   - Pass `lang: currentLang` inside every JSON POST payload in `API` (and query param for GET endpoints if returning localized errors).
   - Ensure `setLanguage(lang)` / `updateDOMTranslations()` also refreshes any dynamically rendered panels or status badges if they don't carry `data-i18n*`.
3. **Backend Messages (`app.py`)**
   - Add every backend response message key to `msgs` in `get_msg(key, lang)` with both `"en"` and `"vi"` entries.
   - Return `get_msg("your_key", data.get("lang", "en"))` inside `{"ok": ..., "message": ...}`.

### Quick EN/VI Key Parity Verification Script
Run from repository root to catch missing or mismatched keys across `templates/index.html`, `static/app.js`, and `app.py`:

```bash
python3 - <<'PY'
import re, pathlib

html = pathlib.Path("templates/index.html").read_text()
js = pathlib.Path("static/app.js").read_text()
py = pathlib.Path("app.py").read_text()

html_keys = set(re.findall(r'data-i18n(?:-(?:placeholder|title))?="([^"]+)"', html))
js_t_keys = set(re.findall(r"\bt\(\s*'([^']+)'", js))

en_block = re.search(r"en:\s*\{(.*?)\n\s*\},\s*\n\s*vi:", js, re.S).group(1)
vi_block = re.search(r"vi:\s*\{(.*?)\n\s*\}\s*\n\};", js, re.S).group(1)
en_keys = set(re.findall(r"^\s*([a-zA-Z0-9_]+):", en_block, re.M))
vi_keys = set(re.findall(r"^\s*([a-zA-Z0-9_]+):", vi_block, re.M))

print("Missing in EN:", sorted((html_keys | js_t_keys) - en_keys))
print("Missing in VI:", sorted((html_keys | js_t_keys) - vi_keys))
print("EN vs VI diff:", sorted(en_keys ^ vi_keys))

msgs_block = re.search(r"msgs\s*=\s*\{(.*?)\n\s*\}", py, re.S).group(1)
py_keys = set(re.findall(r'"([^"]+)":\s*\{', msgs_block))
py_used = set(re.findall(r"get_msg\(\s*['\"]([^'\"]+)['\"]", py))
print("Missing in app.py get_msg:", sorted(py_used - py_keys))
PY
```

### Known Existing Quirks to Watch Out For
When auditing or extending UI files, be aware of these existing quirks (do not copy these anti-patterns into new code):
- `static/app.js` (`translations.vi`): `btn_renaming` currently holds the literal string `"${t('btn_renaming')}"` instead of `"Đang đổi tên..."`.
- `static/app.js` (`browseTo`, `renderTable`): contains hardcoded Vietnamese strings (`'Không có thư mục con'` and `title="Click để xem trước ảnh"`) instead of `t(...)`.
- `templates/index.html` (`#resizer-handle`): has hardcoded Vietnamese `title="Kéo để điều chỉnh kích thước"` without `data-i18n-title`.
- `static/app.js` (`t(key)`): falls back to `key` directly rather than `translations.en[key]` if a key is missing in `translations.vi`.
- `static/app.js` (`setStatus()`): queries `#status-text` and `#status-dot`, neither of which currently exists in `templates/index.html`.

---

## 4. Designing Future Auto-Capture UI & Interactive Canvas Modal

### Auto-Capture Panel
- Place inside `.sidebar-panel` as a `.section` -> `.card` (matching Folder / Range / Notes) or add a compact section/mode switcher in `.content-panel` so the `290px` default sidebar stays uncluttered.
- Include bilingual labels/controls for:
  - **Save Folder**: path input (`.folder-input-wrapper` style) + Browse button reusing `#folder-modal` or dedicated folder picker.
  - **Capture Region**: `(x, y, w, h)` numeric fields (`.range-input` style, `font-variant-numeric: tabular-nums`) + two trigger buttons:
    - **Screen Overlay** (Mode 1 backend)
    - **Test Shot & Pick** (Mode 2 in-app Canvas Modal)
  - **Timer Interval**: range slider or numeric input strictly `min="1" max="10"` seconds (`step="1"`).
  - **Page-Turn Action**: segmented/radio or `<select>` (`.lang-select-container` styling) switching between:
    - **Keyboard Shortcut** (Right Arrow, Left Arrow, Down Arrow, Up Arrow, Space, PageDown, Return)
    - **Fixed Click Point** (`click_x`, `click_y` inputs + Pick Point button)
  - **Capture Sound**: Apple-style toggle switch for default `Grab.aif` shutter sound.
  - **Controls & Live Status**: Primary Start button (`.btn-primary`) switching to Stop button (styled with `--color-error` when running), live captured count pill (`.section-badge`), and a clear permission warning banner if Screen Recording or Accessibility is missing.

### Interactive Region & Click-Point Canvas Modal (Mode 2)
- Reuse `.modal-overlay` + `.modal.image-modal` + `closeModalWithAnimation()`.
- Layout:
  - `.modal-header`: localized title + mode switcher buttons (**Select Region** vs **Select Click Point**), logical resolution / scale readout badge (`.image-counter-badge`), and `.modal-close`.
  - `.modal-body.image-body`: `<canvas>` fitting responsively inside `.image-preview-container` (`object-fit: contain` parity — store exact `image_width`, `image_height`, `screen_width`, `screen_height`, `scale_factor` from `/api/capture/preview-screen`).
  - Canvas overlay visuals:
    - Region box: `--color-primary` stroke (`#0066cc` light / `#0a84ff` dark) with translucent fill and corner resize/drag feedback.
    - Click point crosshair: `--color-warning` (`#ff9500`) or `--color-error` (`#ff3b30`) ring + coordinates pill.
  - Coordinate math in JS: map pointer events using `canvas.getBoundingClientRect()` -> natural `image_width`/`image_height` -> logical screen points (`px / scale_factor`), clamped within `[0, screen_width]` and `[0, screen_height]`.
  - `.modal-footer`: live `(x, y, w, h)` & `(click_x, click_y)` summary + Reset (`.btn-utility`) + Cancel (`.btn-utility`) + Apply/Save (`.btn-primary`).
