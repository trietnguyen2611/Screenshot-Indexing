---
name: macos-capture-automation
description: >-
  Authoritative macOS implementation guide for fixed-region screen capture, Retina HiDPI coordinate math, 1-10s timed capture loops, Grab.aif shutter sound, keyboard and fixed-click page-turn automation, dual region/point selection backends, and TCC permissions. Load before building or reviewing macOS automation modules in services/.
---

# macOS Capture & Automation Guide

All macOS OS-interaction logic belongs in dedicated modules inside `services/` (e.g., `services/macos_capture.py`, `services/macos_input.py`, `services/macos_overlay.py`, `services/macos_sound.py`, `services/macos_permissions.py`) owned by `macos-automation`. Expose clean Python functions/classes with type hints and docstrings so `app.py` (`backend-core`) imports and wires them to Flask routes without mixing Quartz/AppKit details into HTTP handlers.

---

## 1. Fixed-Region Screen Capture & File Saving

### Primary Method: `screencapture -x -R x,y,w,h <output_path>`
```python
cmd = ["screencapture", "-x", "-R", f"{int(x)},{int(y)},{int(w)},{int(h)}", output_path]
```
- **Why `-x` is mandatory**: `-x` disables macOS's built-in camera shutter sound during capture. Always pass `-x` so the application controls audio playback explicitly via the user's capture sound toggle (preventing double sounds or unwanted noise when muted).
- **Coordinate units**: `-R x,y,w,h` expects **logical screen points** (`int(w) > 0` and `int(h) > 0`).
- **Validation**: Check `returncode == 0` AND verify `os.path.isfile(output_path)` with `os.path.getsize(output_path) > 0`. If Screen Recording permission is denied or the rect is off-screen/zero-sized, `screencapture` may exit non-zero or fail to create the file.

### Alternative / Fallback: `Quartz.CGWindowListCreateImage`
When avoiding per-shot subprocess spawn overhead:
- Capture `CGRectMake(x, y, w, h)` using `Quartz.CGWindowListCreateImage(rect, Quartz.kCGWindowListOptionOnScreenOnly, Quartz.kCGNullWindowID, Quartz.kCGWindowImageDefault)` and encode the resulting `CGImageRef` to PNG via `AppKit.NSBitmapImageRep` (`NSPNGFileType`) or `Quartz.CGImageDestination`.
- Note: `screencapture -x -R` handles display scaling and system compositing automatically and is less sensitive to PyObjC memory/ref nuances; keep `CGWindowListCreateImage` as an optional fallback or fast path.

### Save Directory & Collision-Free Filenames
- Always save directly into the **user-configured save folder** (`os.path.isdir(save_dir)` validated before starting capture). Never hardcode `~/Desktop` or `~/Downloads`.
- Generate collision-free filenames compatible with Screenshot-Indexing's chronological conventions (or sequence-safe naming):
  - Example macOS-compatible timestamp name: `Screenshot YYYY-MM-DD at HH.MM.SS.png` (matching `is_screenshot_file` prefix `"screenshot"` and `get_sort_key` `(\d+)\.(\d+)\.(\d+)\.\w+$` in `app.py`).
  - Because intervals can be `1` second (or repeated shots happen within the same second), always deduplicate if `os.path.exists(candidate)` by appending a disambiguating suffix (e.g., `... (1).png` or millisecond/counter suffix while keeping sortable timestamps) before writing.

---

## 2. Default macOS Capture Shutter Sound

- Verified macOS system sound path:
  ```python
  MACOS_CAPTURE_SOUND = (
      "/System/Library/Components/CoreAudio.component/Contents/"
      "SharedSupport/SystemSounds/system/Grab.aif"
  )
  ```
- **Must be non-blocking** so audio playback never delays the capture timer loop:
  - **Option A (`afplay` subprocess)**:
    ```python
    if sound_enabled and os.path.exists(MACOS_CAPTURE_SOUND):
        subprocess.Popen(
            ["afplay", MACOS_CAPTURE_SOUND],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    ```
  - **Option B (`AppKit.NSSound`)**:
    ```python
    sound = AppKit.NSSound.alloc().initWithContentsOfFile_byReference_(MACOS_CAPTURE_SOUND, True)
    if sound:
        sound.play()
    ```
- Guard with `os.path.exists(MACOS_CAPTURE_SOUND)` and catch exceptions cleanly so a missing audio device never aborts a capture loop.

---

## 3. Retina / HiDPI Coordinate Scaling Math

Understanding coordinate spaces prevents off-target regions and clicks on Retina Macs:

- **Logical Screen Points** (`screen_width × screen_height`, e.g., `1440 × 900` or `1512 × 982`):
  - Used by `screencapture -R x,y,w,h`
  - Used by `Quartz.CGDisplayBounds(display_id)`
  - Used by `Quartz.CGEventCreateMouseEvent` (`click_x, click_y`)
- **Physical Image Pixels** (`image_width × image_height`, e.g., `2880 × 1800` on 2× Retina):
  - Produced by full-screen test preview PNG (`screencapture -x <preview_path>`)

### Computing Scale Factor
Query the target display's logical bounds via `Quartz.CGDisplayBounds(Quartz.CGMainDisplayID())` (giving `origin_x`, `origin_y`, `screen_width`, `screen_height`) and read the captured preview PNG's pixel width/height (`image_width`, `image_height`):

```python
scale_x = image_width / screen_width
scale_y = image_height / screen_height
scale_factor = scale_x  # Typically 2.0 on Retina, 1.0 on standard displays
```

### Converting In-App Canvas Coordinates -> Logical Screen Points
When the web UI renders the preview image at CSS/DOM size `(dom_width, dom_height)` inside `<canvas>`:

1. **DOM Canvas coordinates `(dom_x, dom_y, dom_w, dom_h)` -> Preview Image Pixels `(px_x, px_y, px_w, px_h)`**:
   ```text
   px_x = dom_x * (image_width / dom_width)
   px_y = dom_y * (image_height / dom_height)
   px_w = dom_w * (image_width / dom_width)
   px_h = dom_h * (image_height / dom_height)
   ```
2. **Image Pixels -> Logical Screen Points** (either convert on backend from pixel payloads or convert consistently using `scale_factor` / `screen_width`):
   - **Capture Region**:
     ```text
     logical_x = round(origin_x + px_x / scale_x)
     logical_y = round(origin_y + px_y / scale_y)
     logical_w = max(1, round(px_w / scale_x))
     logical_h = max(1, round(px_h / scale_y))
     ```
   - **Page-Turn Click Point**:
     ```text
     logical_click_x = origin_x + px_click_x / scale_x
     logical_click_y = origin_y + px_click_y / scale_y
     ```

### Multi-Display Caveats
- On multi-monitor setups, `CGMainDisplayID()` has origin `(0, 0)`, while secondary displays can have negative `origin_x`/`origin_y` (left/above main display) or offset positive origins, and **different** `backingScaleFactor` values (e.g., `2.0` built-in Retina + `1.0` external monitor).
- `screencapture -x <path>` captures the main display by default (or use `-D <display_index>` / `CGGetActiveDisplayList` to target a specific display). Always store `origin_x`, `origin_y`, `screen_width`, and `screen_height` from the exact captured display when computing coordinates.

---

## 4. Timed Capture Loop (`1–10` Seconds)

Implement a thread-safe capture controller in `services/` (never inside Flask's request thread):

- **Clamp Interval**: Strictly clamp user interval to `[1, 10]` seconds (`interval = max(1.0, min(10.0, float(interval)))`, or integer `1 <= interval <= 10`).
- **Mutual Exclusion**: Guard `start()` / `stop()` with a `threading.Lock()` so a double-click or duplicate API call cannot launch two concurrent capture threads.
- **Immediate Abort via `threading.Event`**:
  - Use `stop_event = threading.Event()` and wait with `stop_event.wait(timeout=interval)` instead of `time.sleep(interval)`.
  - Calling `stop()` sets `stop_event.set()`, waking the loop immediately rather than blocking up to 10 seconds.
- **Per-Iteration Execution Order**:
  1. Check `if stop_event.is_set(): break`.
  2. Capture region `(x, y, w, h)` to collision-free path in `save_dir`.
  3. If capture fails, record `last_error` and either break cleanly or report error state without crashing the thread.
  4. Play `Grab.aif` non-blocking if `sound_enabled` is true.
  5. Increment `captured_count` and update `last_file`.
  6. Check `if stop_event.is_set(): break` before firing page turn (avoids turning an extra page after user pressed Stop).
  7. Trigger configured page-turn action (keyboard shortcut OR fixed click point).
  8. Wait: `stop_event.wait(timeout=interval)`.
- **Status Snapshot**: Expose thread-safe status dict (`running`, `captured_count`, `interval`, `last_file`, `last_error`, `started_at`) for `/api/capture/status`.

---

## 5. Auto Page-Turn Mechanisms (Both Modes Required)

Support BOTH mechanisms cleanly behind a unified dispatcher (`mode: "keyboard" | "click"`):

### Mode A: Keyboard Shortcut Simulation
Primary via `Quartz`:
```python
down = Quartz.CGEventCreateKeyboardEvent(None, keycode, True)
up = Quartz.CGEventCreateKeyboardEvent(None, keycode, False)
# Optional modifiers: Quartz.CGEventSetFlags(down, flags); Quartz.CGEventSetFlags(up, flags)
Quartz.CGEventPost(Quartz.kCGHIDEventTap, down)
Quartz.CGEventPost(Quartz.kCGHIDEventTap, up)
```
Fallback via `osascript` (`System Events`):
```bash
osascript -e 'tell application "System Events" to key code 124'
```
*(Note: `osascript` using `System Events` triggers macOS Automation / `NSAppleEventsUsageDescription` TCC consent in addition to Accessibility.)*

#### macOS Virtual `keyCode` Reference Table
| Key | `keyCode` | Notes |
| :--- | :--- | :--- |
| Right Arrow | `124` | Standard next page / slide |
| Left Arrow | `123` | Standard previous page / slide |
| Down Arrow | `125` | Next item / scroll down |
| Up Arrow | `126` | Previous item / scroll up |
| Space | `49` | Page advance in readers/slides |
| PageDown | `121` | Explicit page down |
| Return | `36` | Confirm / advance |

*(Common extras: `PageUp: 116`, `Tab: 48`, `Escape: 53`.)*

### Mode B: Fixed Coordinate Click `(click_x, click_y)`
Use `Quartz.CGEventCreateMouseEvent` with logical screen points `(float(click_x), float(click_y))`:
```python
point = Quartz.CGPointMake(float(click_x), float(click_y))
move = Quartz.CGEventCreateMouseEvent(None, Quartz.kCGEventMouseMoved, point, Quartz.kCGMouseButtonLeft)
down = Quartz.CGEventCreateMouseEvent(None, Quartz.kCGEventLeftMouseDown, point, Quartz.kCGMouseButtonLeft)
up = Quartz.CGEventCreateMouseEvent(None, Quartz.kCGEventLeftMouseUp, point, Quartz.kCGMouseButtonLeft)

Quartz.CGEventPost(Quartz.kCGHIDEventTap, move)
Quartz.CGEventPost(Quartz.kCGHIDEventTap, down)
time.sleep(0.03)  # Brief hold so target app registers click cleanly
Quartz.CGEventPost(Quartz.kCGHIDEventTap, up)
```

---

## 6. Dual Region & Click-Point Selection Backends

Support BOTH user selection modes:

### Mode 1: Native Screen Overlay / Picker
- Launches a transparent/borderless full-screen macOS overlay selector window (AppKit `NSWindow` with `NSBorderlessWindowMask` and translucent selection rectangle + click-point crosshair) or native picker returning **logical screen coordinates**:
  - Region: `{"x": int, "y": int, "width": int, "height": int}`
  - Click point: `{"click_x": float, "click_y": float}`
- **PyWebView / AppKit Main-Thread Caveat**: macOS requires AppKit UI (`NSWindow`, `NSApplication`) to run on the main thread of its process. Because Flask runs on a background daemon thread in `app.py`, do **not** create `NSWindow` directly inside a Flask route thread! Either:
  - Run the overlay selector in a dedicated helper process (paying attention to frozen PyInstaller `sys.frozen` paths—do not blindly call `sys.executable script.py` inside a bundled `.app` without a dedicated flag/entrypoint), **or**
  - Dispatch safely onto the main Cocoa thread if integrated with PyWebView's runloop.
- Note: `screencapture -i` can select a region interactively to a temp file, **but** does not return `(x, y, w, h)` directly or let users pick `(click_x, click_y)`, so a custom AppKit overlay (or native selector) is needed for full Mode 1 support.

### Mode 2: Full-Screen Test Shot for In-App Canvas
- Captures a temporary full-screen PNG via `screencapture -x <temp_preview_path>` stored in a dedicated temp/app cache directory (never pollute the user's configured screenshot folder!).
- Reads physical `(image_width, image_height)` (for example, PNG `IHDR` header bytes `16:24` via `struct.unpack(">II", data[16:24])` with zero external dependencies, or via `AppKit.NSImageRep`) and logical display bounds `(screen_width, screen_height, origin_x, origin_y)`.
- Returns JSON metadata for the frontend Canvas modal:
  ```json
  {
    "ok": true,
    "image_url": "/api/capture/preview-image?t=...",
    "screen_width": 1512,
    "screen_height": 982,
    "image_width": 3024,
    "image_height": 1964,
    "scale_factor": 2.0,
    "origin_x": 0,
    "origin_y": 0
  }
  ```

---

## 7. TCC Permissions & `Info.plist` Keys

Never bypass macOS TCC prompts or security boundaries. Detect missing permissions cleanly and return structured state so the UI guides the user to **System Settings -> Privacy & Security**:

1. **Screen Recording** (required for `screencapture` & `CGWindowListCreateImage` capturing other windows):
   - Check: `bool(Quartz.CGPreflightScreenCaptureAccess())`
   - Prompt: `Quartz.CGRequestScreenCaptureAccess()`
2. **Accessibility** (required for `CGEventPost` keyboard/mouse simulation and `System Events` keystrokes):
   - Check: `AXIsProcessTrusted()` (via `ApplicationServices` / `HIServices` / `ctypes` wrapping `ApplicationServices.framework`'s `AXIsProcessTrusted()` or `AXIsProcessTrustedWithOptions`).
3. **Required `Info.plist` Keys** (must be injected in the `.app` bundle during CI/PyInstaller packaging):
   - `NSScreenCaptureUsageDescription` — explains why Screenshot Indexing needs Screen Recording access.
   - `NSAppleEventsUsageDescription` — explains why Screenshot Indexing sends page-turn events if `osascript` / AppleEvents automation is used.
