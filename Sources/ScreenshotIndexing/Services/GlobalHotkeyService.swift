import AppKit
@preconcurrency import CoreGraphics
import Foundation

/// Listens for a configurable system-wide and in-app hotkey using a `CGEventTap`
/// (when Accessibility permission is granted) and an AppKit local monitor.
@MainActor
final class GlobalHotkeyService {
    static let shared = GlobalHotkeyService()

    private var activeShortcut: HotkeyShortcut?
    private var handler: (@MainActor () -> Void)?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var localMonitor: Any?
    private var lastTriggerUptime: TimeInterval = 0.0

    private let debounceInterval: TimeInterval = 0.6

    private init() {}

    /// Whether the system-wide `CGEventTap` is currently installed and enabled.
    var isGlobalTapActive: Bool {
        guard let eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    /// Start monitoring system-wide and local `.keyDown` events for `shortcut`.
    /// Safe to call repeatedly: updates the active shortcut/handler and ensures monitors
    /// and the `CGEventTap` are created or re-enabled without duplicating taps.
    func start(shortcut: HotkeyShortcut, handler: @escaping @MainActor () -> Void) {
        self.activeShortcut = shortcut
        self.handler = handler
        installLocalMonitorIfNeeded()
        installOrEnableEventTap()
    }

    /// Re-attempt creating or re-enabling the `CGEventTap` if `start(shortcut:handler:)` is active
    /// and the tap previously failed (e.g., before Accessibility permission was granted) or was disabled.
    func restartIfNeeded() {
        guard activeShortcut != nil, handler != nil else { return }
        installLocalMonitorIfNeeded()
        installOrEnableEventTap()
    }

    /// Update the active hotkey combination without tearing down active monitors.
    func updateShortcut(_ shortcut: HotkeyShortcut) {
        activeShortcut = shortcut
    }

    /// Stop both the `CGEventTap` and local keyboard monitor and release the callback.
    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        activeShortcut = nil
        handler = nil
    }

    // MARK: - Monitor & Tap Lifecycle

    private func installLocalMonitorIfNeeded() {
        guard localMonitor == nil else { return }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.shouldIgnoreForTextInput(modifierFlags: event.modifierFlags) {
                return event
            }
            let keyCode = Int(event.keyCode)
            let flagsRaw = event.modifierFlags.rawValue
            if self.processKeyEvent(keyCode: keyCode, modifierFlagsRaw: flagsRaw) {
                return nil
            }
            return event
        }
    }

    private func installOrEnableEventTap() {
        if let eventTap {
            if !CGEvent.tapIsEnabled(tap: eventTap) {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return
        }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                guard let userInfo else {
                    return Unmanaged.passUnretained(event)
                }
                return MainActor.assumeIsolated {
                    let service = Unmanaged<GlobalHotkeyService>.fromOpaque(userInfo).takeUnretainedValue()
                    return service.handleEventTapCallback(type: type, event: event)
                }
            },
            userInfo: userInfo
        ) else {
            // Accessibility permission is likely not granted yet; localMonitor remains active
            // and restartIfNeeded() will retry once Accessibility is granted.
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
    }

    private func handleEventTapCallback(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let modifierFlags = Self.modifierFlags(from: event.flags)
        if NSApp.isActive, shouldIgnoreForTextInput(modifierFlags: modifierFlags) {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        if processKeyEvent(keyCode: keyCode, modifierFlagsRaw: modifierFlags.rawValue) {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func shouldIgnoreForTextInput(modifierFlags: NSEvent.ModifierFlags) -> Bool {
        let flags = modifierFlags.intersection([.control, .shift, .option, .command])
        return !flags.contains(.control)
            && !flags.contains(.option)
            && !flags.contains(.command)
            && NSApp.keyWindow?.firstResponder is NSText
    }

    private static func modifierFlags(from cgFlags: CGEventFlags) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if cgFlags.contains(.maskControl) { flags.insert(.control) }
        if cgFlags.contains(.maskShift) { flags.insert(.shift) }
        if cgFlags.contains(.maskAlternate) { flags.insert(.option) }
        if cgFlags.contains(.maskCommand) { flags.insert(.command) }
        return flags
    }

    // MARK: - Private Matching & Debounce

    @discardableResult
    private func processKeyEvent(keyCode: Int, modifierFlagsRaw: UInt) -> Bool {
        guard let shortcut = activeShortcut,
              matches(shortcut: shortcut, keyCode: keyCode, modifierFlagsRaw: modifierFlagsRaw) else {
            return false
        }

        let now = ProcessInfo.processInfo.systemUptime
        if now - lastTriggerUptime < debounceInterval {
            return true
        }

        lastTriggerUptime = now
        handler?()
        return true
    }

    private func matches(shortcut: HotkeyShortcut, keyCode: Int, modifierFlagsRaw: UInt) -> Bool {
        let expectedKeyCode = InputSimulationService.macKeyCode(forWebCode: shortcut.code) ?? shortcut.keycode
        guard keyCode == expectedKeyCode else {
            return false
        }

        let flags = NSEvent.ModifierFlags(rawValue: modifierFlagsRaw)
            .intersection([.control, .shift, .option, .command])

        return flags.contains(.control) == shortcut.ctrl
            && flags.contains(.shift) == shortcut.shift
            && flags.contains(.option) == shortcut.alt
            && flags.contains(.command) == shortcut.meta
    }
}
