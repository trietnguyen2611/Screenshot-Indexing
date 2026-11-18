import AppKit
import Foundation

/// Target mode for the full-screen transparent overlay picker.
enum OverlayPickerTarget: Sendable {
    case region
    case click
}

/// Outcome returned by `ScreenOverlayPickerController.pick(target:)`.
enum OverlayPickerResult: Sendable {
    case selectedRegion(CaptureRegion)
    case selectedClick(x: Int, y: Int)
    case cancelled
}

/// Manages an in-process full-screen AppKit overlay window for picking screen regions or click coordinates.
@MainActor
final class ScreenOverlayPickerController {
    static let shared = ScreenOverlayPickerController()

    private var activeWindow: OverlayWindow?
    private var localKeyMonitor: Any?
    private var isPicking = false

    private init() {}

    /// Display the transparent full-screen overlay and suspend until the user selects or cancels.
    func pick(target: OverlayPickerTarget = .region) async -> OverlayPickerResult {
        guard !isPicking else {
            return .cancelled
        }

        let screens = NSScreen.screens
        guard let primaryScreen = screens.first else {
            return .cancelled
        }

        let primaryHeight = primaryScreen.frame.height
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.main
            ?? primaryScreen
        let screenFrame = targetScreen.frame

        isPicking = true

        return await withCheckedContinuation { continuation in
            var hasCompleted = false

            let finish: @MainActor (OverlayPickerResult) -> Void = { [weak self] result in
                guard !hasCompleted else { return }
                hasCompleted = true

                if let monitor = self?.localKeyMonitor {
                    NSEvent.removeMonitor(monitor)
                    self?.localKeyMonitor = nil
                }

                if let win = self?.activeWindow {
                    win.orderOut(nil)
                    win.contentView = nil
                    win.close()
                }
                self?.activeWindow = nil
                self?.isPicking = false

                continuation.resume(returning: result)
            }

            let window = OverlayWindow(
                contentRect: screenFrame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.setFrame(screenFrame, display: true)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

            let localRect = NSRect(origin: .zero, size: screenFrame.size)
            let initialLocalPoint = NSPoint(
                x: mouseLocation.x - screenFrame.origin.x,
                y: mouseLocation.y - screenFrame.origin.y
            )
            let view = OverlayView(
                frame: localRect,
                target: target,
                screenOrigin: screenFrame.origin,
                primaryHeight: primaryHeight,
                initialMousePos: localRect.contains(initialLocalPoint) ? initialLocalPoint : nil,
                onFinish: finish
            )

            window.contentView = view
            self.activeWindow = window

            self.localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // Escape
                    finish(.cancelled)
                    return nil
                }
                return event
            }

            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            window.makeFirstResponder(view)
            window.invalidateCursorRects(for: view)
        }
    }
}

// MARK: - AppKit Overlay Window & Interactive View

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class OverlayView: NSView {
    private let target: OverlayPickerTarget
    private let screenOrigin: NSPoint
    private let primaryHeight: CGFloat
    private let onFinish: @MainActor (OverlayPickerResult) -> Void

    private var dragStart: NSPoint?
    private var dragCurrent: NSPoint?
    private var mousePos: NSPoint?
    private var trackingAreaRef: NSTrackingArea?

    init(
        frame frameRect: NSRect,
        target: OverlayPickerTarget,
        screenOrigin: NSPoint,
        primaryHeight: CGFloat,
        initialMousePos: NSPoint?,
        onFinish: @escaping @MainActor (OverlayPickerResult) -> Void
    ) {
        self.target = target
        self.screenOrigin = screenOrigin
        self.primaryHeight = primaryHeight
        self.mousePos = initialMousePos
        self.onFinish = onFinish
        super.init(frame: frameRect)
        installTrackingArea()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingAreaRef {
            removeTrackingArea(existing)
        }
        installTrackingArea()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Subtle dark scrim over the entire display
        NSColor(calibratedRed: 0.02, green: 0.03, blue: 0.06, alpha: 0.28).setFill()
        bounds.fill()

        // Crosshair guide lines at current pointer
        if let mousePos {
            NSColor(calibratedWhite: 1.0, alpha: 0.36).setStroke()

            let horizontalGuide = NSBezierPath()
            horizontalGuide.lineWidth = 1.0
            horizontalGuide.move(to: NSPoint(x: 0.0, y: mousePos.y))
            horizontalGuide.line(to: NSPoint(x: bounds.width, y: mousePos.y))
            horizontalGuide.stroke()

            let verticalGuide = NSBezierPath()
            verticalGuide.lineWidth = 1.0
            verticalGuide.move(to: NSPoint(x: mousePos.x, y: 0.0))
            verticalGuide.line(to: NSPoint(x: mousePos.x, y: bounds.height))
            verticalGuide.stroke()
        }

        // Smooth rounded region selection box + dimension pill
        if target == .region, let dragStart, let dragCurrent {
            let minX = min(dragStart.x, dragCurrent.x)
            let minY = min(dragStart.y, dragCurrent.y)
            let width = abs(dragCurrent.x - dragStart.x)
            let height = abs(dragCurrent.y - dragStart.y)
            let selectionRect = NSRect(x: minX, y: minY, width: width, height: height)
            let selectionPath = NSBezierPath(roundedRect: selectionRect, xRadius: 8.0, yRadius: 8.0)

            NSColor(calibratedRed: 0.14, green: 0.56, blue: 1.0, alpha: 0.16).setFill()
            selectionPath.fill()

            NSColor(calibratedRed: 0.24, green: 0.64, blue: 1.0, alpha: 0.96).setStroke()
            selectionPath.lineWidth = 2.0
            selectionPath.stroke()

            let dimW = max(10, Int(width.rounded()))
            let dimH = max(10, Int(height.rounded()))
            drawFrostedPill(
                text: "\(dimW) × \(dimH) pt",
                x: minX,
                y: minY + height + 10.0,
                fontSize: 12.0,
                centered: false
            )
        }

        // Target indicator ring + Quartz coordinate pill for click mode
        if target == .click, let mousePos {
            let ringRect = NSRect(x: mousePos.x - 13.0, y: mousePos.y - 13.0, width: 26.0, height: 26.0)
            let ring = NSBezierPath(ovalIn: ringRect)
            NSColor(calibratedRed: 1.0, green: 0.29, blue: 0.25, alpha: 0.24).setFill()
            ring.fill()
            NSColor(calibratedRed: 1.0, green: 0.32, blue: 0.28, alpha: 0.96).setStroke()
            ring.lineWidth = 2.0
            ring.stroke()

            let dotRect = NSRect(x: mousePos.x - 2.5, y: mousePos.y - 2.5, width: 5.0, height: 5.0)
            let dot = NSBezierPath(ovalIn: dotRect)
            NSColor.white.setFill()
            dot.fill()

            let quartzPoint = toQuartzPoint(mousePos)
            drawFrostedPill(
                text: "(\(quartzPoint.x), \(quartzPoint.y))",
                x: mousePos.x + 18.0,
                y: mousePos.y + 18.0,
                fontSize: 12.0,
                centered: false
            )
        }

        // Top frosted hint pill
        let hint: String = switch target {
        case .click:
            "Click anywhere to set page-turn point  •  Esc or Right-Click to cancel"
        case .region:
            "Drag to select capture region  •  Esc or Right-Click to cancel"
        }
        drawFrostedPill(
            text: hint,
            x: bounds.width / 2.0,
            y: bounds.height - 68.0,
            fontSize: 13.0,
            centered: true
        )
    }

    override func mouseMoved(with event: NSEvent) {
        mousePos = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        mousePos = pt

        if target == .click {
            let quartz = toQuartzPoint(pt)
            onFinish(.selectedClick(x: quartz.x, y: quartz.y))
            return
        }

        dragStart = pt
        dragCurrent = pt
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        mousePos = pt
        if target == .region {
            dragCurrent = pt
            needsDisplay = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard target == .region, let dragStart else { return }
        let endPt = convert(event.locationInWindow, from: nil)

        let minLocalX = min(dragStart.x, endPt.x)
        let maxLocalX = max(dragStart.x, endPt.x)
        let minLocalY = min(dragStart.y, endPt.y)
        let maxLocalY = max(dragStart.y, endPt.y)

        let minCocoaX = screenOrigin.x + minLocalX
        let maxCocoaX = screenOrigin.x + maxLocalX
        let minCocoaY = screenOrigin.y + minLocalY
        let maxCocoaY = screenOrigin.y + maxLocalY

        if (maxCocoaX - minCocoaX) < 5.0 || (maxCocoaY - minCocoaY) < 5.0 {
            self.dragStart = nil
            self.dragCurrent = nil
            needsDisplay = true
            return
        }

        // Convert Cocoa bottom-left origin coordinates into Quartz top-left origin coordinates.
        let quartzX = Int(minCocoaX.rounded())
        let quartzY = Int((primaryHeight - maxCocoaY).rounded())
        let width = max(10, Int((maxCocoaX - minCocoaX).rounded()))
        let height = max(10, Int((maxCocoaY - minCocoaY).rounded()))

        let region = CaptureRegion(x: quartzX, y: quartzY, width: width, height: height).normalized()
        onFinish(.selectedRegion(region))
    }

    override func rightMouseDown(with event: NSEvent) {
        onFinish(.cancelled)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onFinish(.cancelled)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onFinish(.cancelled)
    }

    // MARK: - Private Drawing & Coordinate Helpers

    private func installTrackingArea() {
        let options: NSTrackingArea.Options = [
            .mouseMoved,
            .activeAlways,
            .inVisibleRect,
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    private func toQuartzPoint(_ localPoint: NSPoint) -> (x: Int, y: Int) {
        let cocoaX = screenOrigin.x + localPoint.x
        let cocoaY = screenOrigin.y + localPoint.y
        return (
            x: Int(cocoaX.rounded()),
            y: Int((primaryHeight - cocoaY).rounded())
        )
    }

    private func drawFrostedPill(
        text: String,
        x: CGFloat,
        y: CGFloat,
        fontSize: CGFloat,
        centered: Bool
    ) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let nsText = text as NSString
        let textSize = nsText.size(withAttributes: attrs)
        let padX: CGFloat = 14.0
        let padY: CGFloat = 7.0
        let pillW = textSize.width + padX * 2.0
        let pillH = textSize.height + padY * 2.0

        let rawX = centered ? (x - pillW / 2.0) : x
        let pillX = max(10.0, min(bounds.width - pillW - 10.0, rawX))
        let pillY = max(10.0, min(bounds.height - pillH - 10.0, y))

        let pillRect = NSRect(x: pillX, y: pillY, width: pillW, height: pillH)
        let radius = pillH / 2.0
        let bgPath = NSBezierPath(roundedRect: pillRect, xRadius: radius, yRadius: radius)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.35)
        shadow.shadowOffset = NSSize(width: 0.0, height: -2.0)
        shadow.shadowBlurRadius = 10.0
        shadow.set()

        NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.13, alpha: 0.78).setFill()
        bgPath.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor(calibratedWhite: 1.0, alpha: 0.24).setStroke()
        bgPath.lineWidth = 1.0
        bgPath.stroke()

        nsText.draw(at: NSPoint(x: pillX + padX, y: pillY + padY), withAttributes: attrs)
    }
}
