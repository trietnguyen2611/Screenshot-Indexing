import AppKit
import Carbon.HIToolbox
import Foundation

/// Listens for a configurable system-wide and in-app hotkey using Carbon `RegisterEventHotKey`
/// and an AppKit local monitor.
@MainActor
final class GlobalHotkeyService {
    static let shared = GlobalHotkeyService()

    nonisolated private static let hotKeySignature: OSType = 0x5353_4958 // "SSIX"
    nonisolated private static let hotKeyIDValue: UInt32 = 1

    private var activeShortcut: HotkeyShortcut?
    private var handler: (@MainActor () -> Void)?
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var localMonitor: Any?
    private var lastTriggerUptime: TimeInterval = 0.0

    private let debounceInterval: TimeInterval = 0.6

    private init() {}

    /// Whether the system-wide Carbon global hotkey is currently registered.
    var isGlobalTapActive: Bool {
        hotKeyRef != nil
    }

    /// Start monitoring system-wide (Carbon) and local `.keyDown` events for `shortcut`.
    /// Safe to call repeatedly: updates the active shortcut/handler and ensures the
    /// local monitor, Carbon event handler, and registered hotkey are active without duplicating them.
    func start(shortcut: HotkeyShortcut, handler: @escaping @MainActor () -> Void) {
        self.activeShortcut = shortcut
        self.handler = handler
        installLocalMonitorIfNeeded()
        installEventHandlerIfNeeded()
        registerHotKey(for: shortcut)
    }

    /// Re-attempt installing the event handler and registering the Carbon hotkey if
    /// `start(shortcut:handler:)` is active and the hotkey is not currently registered.
    func restartIfNeeded() {
        guard let activeShortcut, handler != nil else { return }
        installLocalMonitorIfNeeded()
        installEventHandlerIfNeeded()
        if hotKeyRef == nil {
            registerHotKey(for: activeShortcut)
        }
    }

    /// Update the active hotkey combination and re-register the Carbon global hotkey if active.
    func updateShortcut(_ shortcut: HotkeyShortcut) {
        activeShortcut = shortcut
        if handler != nil {
            installEventHandlerIfNeeded()
            registerHotKey(for: shortcut)
        }
    }

    /// Unregister the Carbon global hotkey, remove the event handler and local monitor, and clear state.
    func stop() {
        unregisterHotKey()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        activeShortcut = nil
        handler = nil
    }

    // MARK: - Local Monitor & Carbon HotKey Lifecycle

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

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        var handlerRef: EventHandlerRef?

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userInfo in
                guard let event, let userInfo else {
                    return OSStatus(eventNotHandledErr)
                }

                var hotKeyID = EventHotKeyID()
                let paramStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard paramStatus == noErr,
                      hotKeyID.signature == GlobalHotkeyService.hotKeySignature,
                      hotKeyID.id == GlobalHotkeyService.hotKeyIDValue else {
                    return OSStatus(eventNotHandledErr)
                }

                return MainActor.assumeIsolated {
                    let service = Unmanaged<GlobalHotkeyService>.fromOpaque(userInfo).takeUnretainedValue()
                    service.handleCarbonHotKeyPressed()
                    return noErr
                }
            },
            1,
            &eventType,
            userInfo,
            &handlerRef
        )

        if status == noErr, let handlerRef {
            self.eventHandlerRef = handlerRef
        }
    }

    private func registerHotKey(for shortcut: HotkeyShortcut) {
        unregisterHotKey()

        let keyCodeInt = InputSimulationService.macKeyCode(forWebCode: shortcut.code) ?? shortcut.keycode
        guard keyCodeInt >= 0, keyCodeInt <= Int(UInt32.max) else { return }

        var modifiers: UInt32 = 0
        if shortcut.ctrl { modifiers |= UInt32(controlKey) }
        if shortcut.alt { modifiers |= UInt32(optionKey) }
        if shortcut.shift { modifiers |= UInt32(shiftKey) }
        if shortcut.meta { modifiers |= UInt32(cmdKey) }

        let hotKeyID = EventHotKeyID(
            signature: Self.hotKeySignature,
            id: Self.hotKeyIDValue
        )
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCodeInt),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr, let ref {
            self.hotKeyRef = ref
        } else {
            self.hotKeyRef = nil
        }
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func handleCarbonHotKeyPressed() {
        guard activeShortcut != nil else { return }
        triggerHandlerWithDebounce()
    }

    private func shouldIgnoreForTextInput(modifierFlags: NSEvent.ModifierFlags) -> Bool {
        let flags = modifierFlags.intersection([.control, .shift, .option, .command])
        return !flags.contains(.control)
            && !flags.contains(.option)
            && !flags.contains(.command)
            && NSApp.keyWindow?.firstResponder is NSText
    }

    // MARK: - Private Matching & Debounce

    @discardableResult
    private func processKeyEvent(keyCode: Int, modifierFlagsRaw: UInt) -> Bool {
        guard let shortcut = activeShortcut,
              matches(shortcut: shortcut, keyCode: keyCode, modifierFlagsRaw: modifierFlagsRaw) else {
            return false
        }

        triggerHandlerWithDebounce()
        return true
    }

    private func triggerHandlerWithDebounce() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastTriggerUptime < debounceInterval {
            return
        }

        lastTriggerUptime = now
        handler?()
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
