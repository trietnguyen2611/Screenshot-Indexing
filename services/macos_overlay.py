"""Transparent full-screen macOS overlay picker for region & click-point selection."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from typing import Any

_OVERLAY_CLASSES: tuple[type, type] | None = None


def _get_overlay_classes() -> tuple[type, type]:
    """Lazily define and cache PyObjC AppKit window/view classes."""
    global _OVERLAY_CLASSES
    if _OVERLAY_CLASSES is not None:
        return _OVERLAY_CLASSES

    import AppKit
    import Foundation
    import objc

    class OverlayWindow(AppKit.NSWindow):
        """Borderless overlay window capable of receiving key and mouse focus."""

        def canBecomeKeyWindow(self) -> bool:  # noqa: N802
            return True

        def canBecomeMainWindow(self) -> bool:  # noqa: N802
            return True

    class OverlayView(AppKit.NSView):
        """Interactive transparent view rendering live selection guides."""

        @objc.python_method
        def configure(
            self,
            target: str,
            screen_origin_x: float,
            screen_origin_y: float,
            primary_height: float,
            on_finish: Any,
        ) -> None:
            """Initialize overlay picker configuration on the view instance."""
            self._target = target
            self._screen_origin_x = float(screen_origin_x)
            self._screen_origin_y = float(screen_origin_y)
            self._primary_height = float(primary_height)
            self._on_finish = on_finish
            self._drag_start = None
            self._drag_current = None
            self._mouse_pos = None
            self._finished = False

            tracking_options = (
                AppKit.NSTrackingMouseMoved
                | AppKit.NSTrackingActiveAlways
                | AppKit.NSTrackingInVisibleRect
            )
            tracking_area = AppKit.NSTrackingArea.alloc().initWithRect_options_owner_userInfo_(
                self.bounds(), tracking_options, self, None
            )
            self.addTrackingArea_(tracking_area)

        def acceptsFirstResponder(self) -> bool:  # noqa: N802
            return True

        def acceptsFirstMouse_(self, event: Any) -> bool:  # noqa: N802
            return True

        def resetCursorRects(self) -> None:  # noqa: N802
            self.addCursorRect_cursor_(
                self.bounds(), AppKit.NSCursor.crosshairCursor()
            )

        @objc.python_method
        def _finish_once(self, result: dict[str, Any]) -> None:
            if self._finished:
                return
            self._finished = True
            if self._on_finish is not None:
                self._on_finish(result)

        @objc.python_method
        def _to_quartz_point(self, pt: Any) -> tuple[int, int]:
            cocoa_x = self._screen_origin_x + float(pt.x)
            cocoa_y = self._screen_origin_y + float(pt.y)
            return int(round(cocoa_x)), int(round(self._primary_height - cocoa_y))

        @objc.python_method
        def _draw_pill_text(
            self,
            text: str,
            x: float,
            y: float,
            font_size: float = 13.0,
            centered: bool = False,
        ) -> None:
            attrs = {
                AppKit.NSFontAttributeName: AppKit.NSFont.systemFontOfSize_weight_(
                    font_size, AppKit.NSFontWeightMedium
                ),
                AppKit.NSForegroundColorAttributeName: AppKit.NSColor.whiteColor(),
            }
            ns_text = Foundation.NSString.stringWithString_(text)
            text_size = ns_text.sizeWithAttributes_(attrs)
            pad_x = 12.0
            pad_y = 6.0
            pill_w = text_size.width + pad_x * 2
            pill_h = text_size.height + pad_y * 2
            pill_x = x - pill_w / 2.0 if centered else x
            pill_y = y

            bounds = self.bounds()
            pill_x = max(8.0, min(bounds.size.width - pill_w - 8.0, pill_x))
            pill_y = max(8.0, min(bounds.size.height - pill_h - 8.0, pill_y))

            pill_rect = Foundation.NSMakeRect(pill_x, pill_y, pill_w, pill_h)
            bg_path = AppKit.NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(
                pill_rect, 8.0, 8.0
            )
            AppKit.NSColor.colorWithCalibratedRed_green_blue_alpha_(
                0.08, 0.08, 0.1, 0.85
            ).setFill()
            bg_path.fill()

            AppKit.NSColor.colorWithCalibratedRed_green_blue_alpha_(
                1.0, 1.0, 1.0, 0.18
            ).setStroke()
            bg_path.setLineWidth_(1.0)
            bg_path.stroke()

            ns_text.drawAtPoint_withAttributes_(
                Foundation.NSMakePoint(pill_x + pad_x, pill_y + pad_y),
                attrs,
            )

        def drawRect_(self, dirty_rect: Any) -> None:  # noqa: N802
            bounds = self.bounds()
            AppKit.NSColor.colorWithCalibratedRed_green_blue_alpha_(
                0.0, 0.0, 0.0, 0.25
            ).setFill()
            AppKit.NSBezierPath.fillRect_(bounds)

            # Subtle crosshair guide lines at current pointer
            if self._mouse_pos is not None:
                AppKit.NSColor.colorWithCalibratedRed_green_blue_alpha_(
                    1.0, 1.0, 1.0, 0.35
                ).setStroke()
                guide_h = AppKit.NSBezierPath.bezierPath()
                guide_h.setLineWidth_(1.0)
                guide_h.moveToPoint_(Foundation.NSMakePoint(0.0, self._mouse_pos.y))
                guide_h.lineToPoint_(
                    Foundation.NSMakePoint(bounds.size.width, self._mouse_pos.y)
                )
                guide_h.stroke()

                guide_v = AppKit.NSBezierPath.bezierPath()
                guide_v.setLineWidth_(1.0)
                guide_v.moveToPoint_(Foundation.NSMakePoint(self._mouse_pos.x, 0.0))
                guide_v.lineToPoint_(
                    Foundation.NSMakePoint(self._mouse_pos.x, bounds.size.height)
                )
                guide_v.stroke()

            if (
                self._target == "region"
                and self._drag_start is not None
                and self._drag_current is not None
            ):
                min_x = min(self._drag_start.x, self._drag_current.x)
                min_y = min(self._drag_start.y, self._drag_current.y)
                width = abs(self._drag_current.x - self._drag_start.x)
                height = abs(self._drag_current.y - self._drag_start.y)
                sel_rect = Foundation.NSMakeRect(min_x, min_y, width, height)

                AppKit.NSColor.colorWithCalibratedRed_green_blue_alpha_(
                    0.04, 0.52, 1.0, 0.16
                ).setFill()
                AppKit.NSBezierPath.fillRect_(sel_rect)

                AppKit.NSColor.colorWithCalibratedRed_green_blue_alpha_(
                    0.04, 0.52, 1.0, 0.95
                ).setStroke()
                border = AppKit.NSBezierPath.bezierPathWithRect_(sel_rect)
                border.setLineWidth_(2.0)
                border.stroke()

                dim_w = max(10, int(round(width)))
                dim_h = max(10, int(round(height)))
                self._draw_pill_text(
                    f"{dim_w} × {dim_h} pt",
                    min_x,
                    min_y + height + 8.0,
                    font_size=12.0,
                )

            if self._target == "click" and self._mouse_pos is not None:
                cx = self._mouse_pos.x
                cy = self._mouse_pos.y
                ring_rect = Foundation.NSMakeRect(cx - 12.0, cy - 12.0, 24.0, 24.0)
                ring = AppKit.NSBezierPath.bezierPathWithOvalInRect_(ring_rect)
                AppKit.NSColor.colorWithCalibratedRed_green_blue_alpha_(
                    1.0, 0.27, 0.23, 0.25
                ).setFill()
                ring.fill()
                AppKit.NSColor.colorWithCalibratedRed_green_blue_alpha_(
                    1.0, 0.27, 0.23, 0.95
                ).setStroke()
                ring.setLineWidth_(2.0)
                ring.stroke()

                qx, qy = self._to_quartz_point(self._mouse_pos)
                self._draw_pill_text(
                    f"({qx}, {qy})",
                    cx + 16.0,
                    cy + 16.0,
                    font_size=12.0,
                )

            hint = (
                "Click anywhere to set page-turn point  •  Esc or Right-Click to cancel"
                if self._target == "click"
                else "Drag to select capture region  •  Esc or Right-Click to cancel"
            )
            self._draw_pill_text(
                hint,
                bounds.size.width / 2.0,
                bounds.size.height - 64.0,
                font_size=13.0,
                centered=True,
            )

        def mouseMoved_(self, event: Any) -> None:  # noqa: N802
            self._mouse_pos = self.convertPoint_fromView_(
                event.locationInWindow(), None
            )
            self.setNeedsDisplay_(True)

        def mouseDown_(self, event: Any) -> None:  # noqa: N802
            pt = self.convertPoint_fromView_(event.locationInWindow(), None)
            self._mouse_pos = pt
            if self._target == "click":
                qx, qy = self._to_quartz_point(pt)
                self._finish_once(
                    {
                        "ok": True,
                        "cancelled": False,
                        "click_point": {"click_x": qx, "click_y": qy},
                    }
                )
                return

            self._drag_start = pt
            self._drag_current = pt
            self.setNeedsDisplay_(True)

        def mouseDragged_(self, event: Any) -> None:  # noqa: N802
            pt = self.convertPoint_fromView_(event.locationInWindow(), None)
            self._mouse_pos = pt
            if self._target == "region":
                self._drag_current = pt
                self.setNeedsDisplay_(True)

        def mouseUp_(self, event: Any) -> None:  # noqa: N802
            if self._target != "region" or self._drag_start is None:
                return
            end_pt = self.convertPoint_fromView_(event.locationInWindow(), None)
            min_local_x = min(self._drag_start.x, end_pt.x)
            max_local_x = max(self._drag_start.x, end_pt.x)
            min_local_y = min(self._drag_start.y, end_pt.y)
            max_local_y = max(self._drag_start.y, end_pt.y)

            min_x = self._screen_origin_x + float(min_local_x)
            max_x = self._screen_origin_x + float(max_local_x)
            min_y = self._screen_origin_y + float(min_local_y)
            max_y = self._screen_origin_y + float(max_local_y)

            quartz_x = int(round(min_x))
            quartz_y = int(round(self._primary_height - max_y))
            width = max(10, int(round(max_x - min_x)))
            height = max(10, int(round(max_y - min_y)))

            self._finish_once(
                {
                    "ok": True,
                    "cancelled": False,
                    "region": {
                        "x": quartz_x,
                        "y": quartz_y,
                        "width": width,
                        "height": height,
                    },
                }
            )

        def rightMouseDown_(self, event: Any) -> None:  # noqa: N802
            self._finish_once(
                {
                    "ok": False,
                    "cancelled": True,
                    "message": "Overlay selection cancelled",
                }
            )

        def keyDown_(self, event: Any) -> None:  # noqa: N802
            if event.keyCode() == 53:  # Escape
                self._finish_once(
                    {
                        "ok": False,
                        "cancelled": True,
                        "message": "Overlay selection cancelled",
                    }
                )

        def cancelOperation_(self, sender: Any) -> None:  # noqa: N802
            self._finish_once(
                {
                    "ok": False,
                    "cancelled": True,
                    "message": "Overlay selection cancelled",
                }
            )

    _OVERLAY_CLASSES = (OverlayWindow, OverlayView)
    return _OVERLAY_CLASSES


def run_overlay_cli(target: str = "region") -> int:
    """Run the full-screen AppKit overlay picker on the process main thread.

    Prints a single JSON payload to stdout and exits cleanly.

    Args:
        target: Either ``"region"`` (drag bounding box) or ``"click"`` (single
            click coordinate).

    Returns:
        Process exit code (0 on selection or clean cancel, 1 on fatal error).
    """
    normalized_target = "click" if target == "click" else "region"
    if sys.platform != "darwin":
        print(
            json.dumps(
                {
                    "ok": False,
                    "cancelled": False,
                    "message": "Overlay picker is only supported on macOS",
                }
            ),
            flush=True,
        )
        return 1

    try:
        import AppKit
        import Foundation

        OverlayWindow, OverlayView = _get_overlay_classes()
        app = AppKit.NSApplication.sharedApplication()
        app.setActivationPolicy_(AppKit.NSApplicationActivationPolicyAccessory)

        screens = AppKit.NSScreen.screens()
        if not screens:
            raise RuntimeError("No active NSScreen available")
        primary_height = float(screens[0].frame().size.height)
        main_screen = AppKit.NSScreen.mainScreen() or screens[0]
        screen_frame = main_screen.frame()

        result_holder: dict[str, Any] = {
            "result": {
                "ok": False,
                "cancelled": True,
                "message": "Overlay selection cancelled",
            }
        }

        window = OverlayWindow.alloc().initWithContentRect_styleMask_backing_defer_(
            screen_frame,
            AppKit.NSBorderlessWindowMask,
            AppKit.NSBackingStoreBuffered,
            False,
        )
        window.setLevel_(AppKit.NSScreenSaverWindowLevel)
        window.setOpaque_(False)
        window.setBackgroundColor_(AppKit.NSColor.clearColor())
        window.setIgnoresMouseEvents_(False)
        window.setAcceptsMouseMovedEvents_(True)
        collection_behavior = AppKit.NSWindowCollectionBehaviorCanJoinAllSpaces
        full_screen_aux = getattr(
            AppKit, "NSWindowCollectionBehaviorFullScreenAuxiliary", 0
        )
        window.setCollectionBehavior_(collection_behavior | full_screen_aux)

        def on_finish(res: dict[str, Any]) -> None:
            result_holder["result"] = res
            window.orderOut_(None)
            app.stop_(None)
            dummy_event = AppKit.NSEvent.otherEventWithType_location_modifierFlags_timestamp_windowNumber_context_subtype_data1_data2_(
                AppKit.NSEventTypeApplicationDefined,
                Foundation.NSMakePoint(0, 0),
                0,
                0.0,
                0,
                None,
                0,
                0,
                0,
            )
            if dummy_event is not None:
                app.postEvent_atStart_(dummy_event, True)

        local_rect = Foundation.NSMakeRect(
            0.0, 0.0, screen_frame.size.width, screen_frame.size.height
        )
        view = OverlayView.alloc().initWithFrame_(local_rect)
        view.configure(
            target=normalized_target,
            screen_origin_x=screen_frame.origin.x,
            screen_origin_y=screen_frame.origin.y,
            primary_height=primary_height,
            on_finish=on_finish,
        )
        window.setContentView_(view)
        window.makeKeyAndOrderFront_(None)
        window.makeFirstResponder_(view)
        app.activateIgnoringOtherApps_(True)
        app.run()

        print(json.dumps(result_holder["result"]), flush=True)
        return 0
    except Exception as exc:
        print(
            json.dumps(
                {"ok": False, "cancelled": False, "message": str(exc)}
            ),
            flush=True,
        )
        return 1


def pick_screen_overlay(target: str = "region") -> dict[str, Any]:
    """Launch the screen overlay picker in a dedicated subprocess.

    Running AppKit UI inside a subprocess ensures ``NSWindow`` runs on its own
    main Cocoa thread without conflicting with Flask or PyWebView.

    Args:
        target: Selection mode (``"region"`` or ``"click"``).

    Returns:
        Dictionary with ``ok``, ``cancelled``, and either ``region``,
        ``click_point``, or ``message``.
    """
    normalized_target = "click" if target == "click" else "region"
    if sys.platform != "darwin":
        return {
            "ok": False,
            "cancelled": False,
            "message": "Overlay picker is only supported on macOS",
        }

    if getattr(sys, "frozen", False):
        cmd = [sys.executable, "--overlay-picker", normalized_target]
        cwd = None
    else:
        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        cmd = [
            sys.executable,
            "-m",
            "services.macos_overlay",
            "--target",
            normalized_target,
        ]
        cwd = project_root

    try:
        proc = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=180,
        )
    except subprocess.TimeoutExpired:
        return {
            "ok": False,
            "cancelled": True,
            "message": "Overlay selection timed out",
        }
    except Exception as exc:
        return {
            "ok": False,
            "cancelled": False,
            "message": str(exc),
        }

    stdout_lines = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
    for line in reversed(stdout_lines):
        try:
            payload = json.loads(line)
            if isinstance(payload, dict) and "ok" in payload:
                payload.setdefault("cancelled", not payload["ok"])
                return payload
        except json.JSONDecodeError:
            continue

    err_msg = proc.stderr.strip() or f"Overlay picker failed (exit {proc.returncode})"
    return {
        "ok": False,
        "cancelled": False,
        "message": err_msg,
    }


def _main() -> int:
    parser = argparse.ArgumentParser(
        description="macOS full-screen overlay region/click picker"
    )
    parser.add_argument(
        "--target",
        choices=["region", "click"],
        default="region",
        help="Selection target mode",
    )
    args = parser.parse_args()
    return run_overlay_cli(target=args.target)


if __name__ == "__main__":
    sys.exit(_main())
