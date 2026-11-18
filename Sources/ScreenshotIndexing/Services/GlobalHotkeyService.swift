import AppKit
import Foundation

/// Listens for a configurable system-wide and in-app hotkey using AppKit global + local monitors.
@MainActor
final class GlobalHotkeyService {
    static let shared = GlobalHotkeyService()

    private var activeShortcut: HotkeyShortcut?
    private var handler: (@MainActor () -> Void)?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastTriggerUptime: TimeInterval = 0.0

    private let debounceInterval: TimeInterval = 0.6

    private init() {}

    /// Start monitoring system-wide and local `.keyDown` events for `shortcut`.
    func start(shortcut: HotkeyShortcut, handler: @escaping @MainActor () -> Void) {
        stop()
        self.activeShortcut = shortcut
        self.handler = handler

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = Int(event.keyCode)
            let flagsRaw = event.modifierFlags.rawValue
            Task { @MainActor [weak self] in
                self?.processKeyEvent(keyCode: keyCode, modifierFlagsRaw: flagsRaw)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let flags = event.modifierFlags.intersection([.control, .shift, .option, .command])
            if !flags.contains(.control) && !flags.contains(.option) && !flags.contains(.command),
               NSApp.keyWindow?.firstResponder is NSText {
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

    /// Update the active hotkey combination without tearing down active monitors.
    func updateShortcut(_ shortcut: HotkeyShortcut) {
        activeShortcut = shortcut
    }

    /// Stop both global and local keyboard monitors and release the callback.
    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        handler = nil
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
