import AppKit
import CoreGraphics
import Foundation

/// macOS virtual key mapping, target-window detection, keyboard/mouse event simulation, and shutter audio.
enum InputSimulationService {
    private static let letterKeyCodes: [String: Int] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6,
        "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14,
        "r": 15, "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35,
        "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
    ]

    private static let digitKeyCodes: [String: Int] = [
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "9": 25, "7": 26, "8": 28, "0": 29,
    ]

    /// Full macOS ANSI virtual keyCode map ported from `services/macos_input.py`.
    static let keyCodeMap: [String: Int] = {
        var map: [String: Int] = [
            "ArrowRight": 124,
            "Right": 124,
            "ArrowLeft": 123,
            "Left": 123,
            "ArrowDown": 125,
            "Down": 125,
            "ArrowUp": 126,
            "Up": 126,
            "Space": 49,
            " ": 49,
            "Spacebar": 49,
            "PageDown": 121,
            "PageUp": 116,
            "Enter": 36,
            "Return": 36,
            "NumpadEnter": 36,
            "Tab": 48,
            "Escape": 53,
            "Esc": 53,
            "Home": 115,
            "End": 119,
            "Backspace": 51,
            "Delete": 117,
            "Period": 47,
            ".": 47,
            "Comma": 43,
            ",": 43,
            "Slash": 44,
            "/": 44,
            "Semicolon": 41,
            ";": 41,
            "Quote": 39,
            "'": 39,
            "BracketLeft": 33,
            "[": 33,
            "BracketRight": 30,
            "]": 30,
            "Backslash": 42,
            "\\": 42,
            "Minus": 27,
            "-": 27,
            "Equal": 24,
            "=": 24,
            "Backquote": 50,
            "`": 50,
            "F1": 122,
            "F2": 120,
            "F3": 99,
            "F4": 118,
            "F5": 96,
            "F6": 97,
            "F7": 98,
            "F8": 100,
            "F9": 101,
            "F10": 109,
            "F11": 103,
            "F12": 111,
        ]

        for (ch, code) in letterKeyCodes {
            let upper = ch.uppercased()
            map[ch] = code
            map[upper] = code
            map["Key\(upper)"] = code
        }

        for (digit, code) in digitKeyCodes {
            map[digit] = code
            map["Digit\(digit)"] = code
        }

        return map
    }()

    private static let keyCodeLowerMap: [String: Int] = {
        var lowered: [String: Int] = [:]
        for (key, value) in keyCodeMap {
            lowered[key.lowercased()] = value
        }
        return lowered
    }()

    /// Web KeyboardEvent.code -> macOS CGKeyCode map ported from `services/macos_hotkey.py`.
    private static let webCodeToMacKeyCode: [String: Int] = {
        var map: [String: Int] = [
            "Equal": 24,
            "Minus": 27,
            "BracketRight": 30,
            "BracketLeft": 33,
            "Enter": 36,
            "Quote": 39,
            "Semicolon": 41,
            "Backslash": 42,
            "Comma": 43,
            "Slash": 44,
            "Period": 47,
            "Tab": 48,
            "Space": 49,
            "Backquote": 50,
            "Backspace": 51,
            "Escape": 53,
            "F1": 122,
            "F2": 120,
            "F3": 99,
            "F4": 118,
            "F5": 96,
            "F6": 97,
            "F7": 98,
            "F8": 100,
            "F9": 101,
            "F10": 109,
            "F11": 103,
            "F12": 111,
        ]
        for (ch, code) in letterKeyCodes {
            map["Key\(ch.uppercased())"] = code
        }
        for (digit, code) in digitKeyCodes {
            map["Digit\(digit)"] = code
        }
        return map
    }()

    private static let macKeyCodeToWebCode: [Int: String] = {
        var reverse: [Int: String] = [:]
        for (webCode, macCode) in webCodeToMacKeyCode {
            reverse[macCode] = webCode
        }
        reverse[76] = "Enter" // Numpad Enter
        return reverse
    }()

    private static let functionKeyCodes: Set<Int> = [
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,
    ]

    private static let namedKeyByMacCode: [Int: (keyName: String, display: String)] = [
        124: ("ArrowRight", "→ ArrowRight"),
        123: ("ArrowLeft", "← ArrowLeft"),
        125: ("ArrowDown", "↓ ArrowDown"),
        126: ("ArrowUp", "↑ ArrowUp"),
        49: ("Space", "␣ Space"),
        121: ("PageDown", "⇟ PageDown"),
        116: ("PageUp", "⇞ PageUp"),
        36: ("Enter", "↵ Enter"),
        76: ("Enter", "↵ Enter"),
        48: ("Tab", "⇥ Tab"),
        53: ("Escape", "⎋ Escape"),
        51: ("Backspace", "⌫ Backspace"),
        117: ("Delete", "⌦ Delete"),
        115: ("Home", "↖ Home"),
        119: ("End", "↘ End"),
        122: ("F1", "F1"),
        120: ("F2", "F2"),
        99: ("F3", "F3"),
        118: ("F4", "F4"),
        96: ("F5", "F5"),
        97: ("F6", "F6"),
        98: ("F7", "F7"),
        100: ("F8", "F8"),
        101: ("F9", "F9"),
        109: ("F10", "F10"),
        103: ("F11", "F11"),
        111: ("F12", "F12"),
        47: (".", "."),
        43: (",", ","),
        44: ("/", "/"),
        41: (";", ";"),
        39: ("'", "'"),
        33: ("[", "["),
        30: ("]", "]"),
        42: ("\\", "\\"),
        27: ("-", "-"),
        24: ("=", "="),
        50: ("`", "`"),
    ]

    private static let letterByMacCode: [Int: String] = {
        var reverse: [Int: String] = [:]
        for (ch, code) in letterKeyCodes {
            reverse[code] = ch
        }
        return reverse
    }()

    private static let digitByMacCode: [Int: String] = {
        var reverse: [Int: String] = [:]
        for (digit, code) in digitKeyCodes {
            reverse[code] = digit
        }
        return reverse
    }()

    private static let ignoredWindowOwners: Set<String> = [
        "Window Server",
        "WindowManager",
        "Dock",
        "Control Center",
        "Notification Center",
        "Screenshot Indexing",
        "ScreenshotIndexing",
        "Python",
        "python3",
        "python3.11",
        "python3.15",
        "CursorUIViewService",
        "Siri",
        "Spotlight",
        "SystemUIServer",
        "Open and Save Panel Service",
        "universalAccessAuthWarn",
        "CoreServicesUIAgent",
        "UserNotificationCenter",
    ]

    private static let lowPriorityWindowOwners: Set<String> = [
        "Finder",
        "Antigravity",
        "Code",
        "Terminal",
        "iTerm2",
    ]

    private static let systemUIOwners: Set<String> = [
        "Window Server",
        "WindowManager",
        "Dock",
        "Control Center",
        "Notification Center",
        "CursorUIViewService",
        "Siri",
        "Spotlight",
        "SystemUIServer",
        "universalAccessAuthWarn",
        "CoreServicesUIAgent",
        "UserNotificationCenter",
    ]

    private static let minFullWindowWidth: Double = 200.0
    private static let minFullWindowHeight: Double = 150.0
    private static let modifierClearMask: UInt64 = 0x100000 | 0x20000 | 0x80000 | 0x40000
    private static let macOSShutterSoundPath =
        "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Grab.aif"

    private static let soundPlaybackCoordinator = ShutterSoundCoordinator()

    // MARK: - Key Resolution & Recording

    /// Resolve a key name or explicit virtual keyCode to a macOS virtual keyCode.
    static func resolveKeyCode(keyName: String = "ArrowRight", keyCode: Int? = nil) -> Int {
        if !keyName.isEmpty {
            if let exact = keyCodeMap[keyName] {
                return exact
            }
            let trimmed = keyName.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmedMatch = keyCodeMap[trimmed] {
                return trimmedMatch
            }
            let lowered = keyName.lowercased()
            if let loweredMatch = keyCodeLowerMap[lowered] {
                return loweredMatch
            }
            if let trimmedLowerMatch = keyCodeLowerMap[trimmed.lowercased()] {
                return trimmedLowerMatch
            }
        }

        if let keyCode, keyCode >= 0 {
            return keyCode
        }
        return 124
    }

    /// Resolve a Web KeyboardEvent.code string (e.g. `"KeyR"`, `"F5"`) to a macOS virtual keyCode.
    static func macKeyCode(forWebCode code: String) -> Int? {
        webCodeToMacKeyCode[code.trimmingCharacters(in: .whitespacesAndNewlines)]
    }

    /// Format a canonical keyName for UI display (e.g., `"ArrowRight"` -> `"→ ArrowRight"`).
    static func displayName(for keyName: String) -> String {
        let code = resolveKeyCode(keyName: keyName)
        if let named = namedKeyByMacCode[code] {
            return named.display
        }
        if keyName.count == 1 {
            return keyName.uppercased()
        }
        return keyName.isEmpty ? "→ ArrowRight" : keyName
    }

    /// Extract normalized `(keyName, keyCode, display)` metadata from an AppKit key event for the UI Key Recorder.
    static func keyMetadata(from event: NSEvent) -> (keyName: String, keyCode: Int, display: String) {
        let rawCode = Int(event.keyCode)

        if let named = namedKeyByMacCode[rawCode] {
            let normalizedCode = rawCode == 76 ? 36 : rawCode
            return (keyName: named.keyName, keyCode: normalizedCode, display: named.display)
        }
        if let letter = letterByMacCode[rawCode] {
            return (keyName: letter, keyCode: rawCode, display: letter.uppercased())
        }
        if let digit = digitByMacCode[rawCode] {
            return (keyName: digit, keyCode: rawCode, display: digit)
        }

        if let chars = event.charactersIgnoringModifiers?.trimmingCharacters(in: .controlCharacters),
           !chars.isEmpty {
            let lowered = chars.lowercased()
            return (keyName: lowered, keyCode: rawCode, display: chars.uppercased())
        }

        let fallbackName = "Key\(rawCode)"
        return (keyName: fallbackName, keyCode: rawCode, display: fallbackName)
    }

    /// Convert an AppKit `.keyDown` event into a `HotkeyShortcut`, requiring at least one modifier or function key.
    static func shortcutMetadata(from event: NSEvent) -> HotkeyShortcut? {
        let rawCode = Int(event.keyCode)
        let flags = event.modifierFlags.intersection([.control, .shift, .option, .command])
        let ctrl = flags.contains(.control)
        let shift = flags.contains(.shift)
        let alt = flags.contains(.option)
        let meta = flags.contains(.command)

        let hasModifier = ctrl || shift || alt || meta
        let isFunctionKey = functionKeyCodes.contains(rawCode)
        guard hasModifier || isFunctionKey else {
            return nil
        }

        guard let webCode = macKeyCodeToWebCode[rawCode] else {
            return nil
        }

        let canonicalKeycode = rawCode == 76 ? 36 : rawCode
        return HotkeyShortcut(
            code: webCode,
            keycode: canonicalKeycode,
            ctrl: ctrl,
            shift: shift,
            alt: alt,
            meta: meta
        )
    }

    // MARK: - Window Detection & App Activation

    /// Find the PID of the external application window overlapping `region`, handling Stage Manager strips.
    static func findTargetPID(for region: CaptureRegion?) -> pid_t? {
        guard let onscreenWins = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]], !onscreenWins.isEmpty else {
            return nil
        }

        let myPID = ProcessInfo.processInfo.processIdentifier
        let regionBox = parseRegionBox(region)

        var onscreenPIDs: Set<pid_t> = []
        var firstOnscreenPID: pid_t?
        var onscreenLowOverlap: pid_t?
        var onscreenFallbackPrimary: pid_t?
        var onscreenFallbackLow: pid_t?

        for win in onscreenWins {
            guard (win[kCGWindowLayer as String] as? Int ?? -1) == 0,
                  let pidNum = win[kCGWindowOwnerPID as String] as? NSNumber else {
                continue
            }
            let pid = pid_t(pidNum.int32Value)
            let owner = win[kCGWindowOwnerName as String] as? String ?? ""
            if pid == myPID || ignoredWindowOwners.contains(owner) {
                continue
            }

            if onscreenPIDs.insert(pid).inserted && firstOnscreenPID == nil {
                firstOnscreenPID = pid
            }

            let bounds = windowBounds(win)
            guard isFullWindow(width: bounds.width, height: bounds.height) else {
                continue
            }

            let isLow = lowPriorityWindowOwners.contains(owner)
            if !isLow && onscreenFallbackPrimary == nil {
                onscreenFallbackPrimary = pid
            } else if isLow && onscreenFallbackLow == nil {
                onscreenFallbackLow = pid
            }

            if overlapsRegion(bounds: bounds, regionBox: regionBox) {
                if !isLow {
                    return pid
                }
                if onscreenLowOverlap == nil {
                    onscreenLowOverlap = pid
                }
            }
        }

        if let allWins = CGWindowListCopyWindowInfo(
            [.excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] {
            var stageLowOverlap: pid_t?
            var stageFallbackPrimary: pid_t?

            for win in allWins {
                guard (win[kCGWindowLayer as String] as? Int ?? -1) == 0,
                      let pidNum = win[kCGWindowOwnerPID as String] as? NSNumber else {
                    continue
                }
                let pid = pid_t(pidNum.int32Value)
                let owner = win[kCGWindowOwnerName as String] as? String ?? ""
                if pid == myPID || ignoredWindowOwners.contains(owner) || !onscreenPIDs.contains(pid) {
                    continue
                }

                let bounds = windowBounds(win)
                guard isFullWindow(width: bounds.width, height: bounds.height) else {
                    continue
                }

                let isLow = lowPriorityWindowOwners.contains(owner)
                if !isLow && stageFallbackPrimary == nil {
                    stageFallbackPrimary = pid
                }

                if overlapsRegion(bounds: bounds, regionBox: regionBox) {
                    if !isLow {
                        return pid
                    }
                    if stageLowOverlap == nil {
                        stageLowOverlap = pid
                    }
                }
            }

            return onscreenLowOverlap
                ?? stageLowOverlap
                ?? onscreenFallbackPrimary
                ?? stageFallbackPrimary
                ?? onscreenFallbackLow
                ?? firstOnscreenPID
        }

        return onscreenLowOverlap
            ?? onscreenFallbackPrimary
            ?? onscreenFallbackLow
            ?? firstOnscreenPID
    }

    /// Bring the application owning `pid` to the foreground if it is not already topmost.
    @discardableResult
    static func activateTargetApp(pid: pid_t?) -> Bool {
        guard let pid, pid > 0, pid != ProcessInfo.processInfo.processIdentifier else {
            return false
        }

        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let isFront = frontPID == pid
        let topmostPID = topmostFullWindowPID()
        let isTopmost = topmostPID == nil || topmostPID == pid
        if isFront && isTopmost {
            return true
        }

        guard let runningApp = NSRunningApplication(processIdentifier: pid) else {
            return false
        }

        let activated = runningApp.activate()
        if activated {
            Thread.sleep(forTimeInterval: 0.12)
        }
        return activated
    }

    // MARK: - Event Simulation & Audio

    /// Simulate a keyboard key press and release via `CGEvent`, falling back to `osascript`.
    static func sendKeyboardShortcut(keyCode: Int, targetPID: pid_t? = nil) -> Bool {
        guard keyCode >= 0 else { return false }

        if let targetPID {
            _ = activateTargetApp(pid: targetPID)
        }

        if let source = CGEventSource(stateID: .hidSystemState),
           let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false) {
            for ev in [keyDown, keyUp] {
                let cleared = ev.flags.rawValue & ~modifierClearMask
                ev.flags = CGEventFlags(rawValue: cleared)
            }
            keyDown.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.035)
            keyUp.post(tap: .cghidEventTap)
            return true
        }

        return sendKeyboardShortcutViaAppleScript(keyCode: keyCode)
    }

    /// Simulate a left mouse click at logical Quartz screen coordinates `(x, y)`.
    static func sendMouseClick(x: Double, y: Double) -> Bool {
        let point = CGPoint(x: x, y: y)
        guard let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ), let downEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        ), let upEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            return false
        }

        moveEvent.post(tap: .cghidEventTap)
        downEvent.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.03)
        upEvent.post(tap: .cghidEventTap)
        return true
    }

    /// Dispatch the configured automated page-turn action (keyboard shortcut or mouse click).
    static func triggerPageTurn(config: PageTurnConfig, targetPID: pid_t? = nil) -> Bool {
        guard config.enabled else { return false }

        switch config.mode {
        case .click:
            return sendMouseClick(x: Double(config.clickX), y: Double(config.clickY))
        case .keyboard:
            let resolvedCode = resolveKeyCode(keyName: config.keyName, keyCode: config.keyCode)
            return sendKeyboardShortcut(keyCode: resolvedCode, targetPID: targetPID)
        }
    }

    /// Play the macOS shutter sound non-blocking via `NSSound`, falling back to `afplay`.
    static func playShutterSound(enabled: Bool) {
        guard enabled, FileManager.default.fileExists(atPath: macOSShutterSoundPath) else {
            return
        }
        soundPlaybackCoordinator.play(path: macOSShutterSoundPath)
    }

    // MARK: - Private Helpers

    private static func windowBounds(_ win: [String: Any]) -> CGRect {
        guard let dict = win[kCGWindowBounds as String] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: dict) else {
            return .zero
        }
        return rect
    }

    private static func isFullWindow(width: CGFloat, height: CGFloat) -> Bool {
        Double(width) >= minFullWindowWidth && Double(height) >= minFullWindowHeight
    }

    private static func parseRegionBox(_ region: CaptureRegion?) -> CGRect? {
        guard let region, region.width > 0, region.height > 0 else {
            return nil
        }
        return CGRect(x: region.x, y: region.y, width: region.width, height: region.height)
    }

    private static func overlapsRegion(bounds: CGRect, regionBox: CGRect?) -> Bool {
        guard let regionBox else { return true }
        return bounds.intersects(regionBox)
    }

    private static func topmostFullWindowPID() -> pid_t? {
        guard let wins = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        for win in wins {
            guard (win[kCGWindowLayer as String] as? Int ?? -1) == 0,
                  let pidNum = win[kCGWindowOwnerPID as String] as? NSNumber else {
                continue
            }
            let owner = win[kCGWindowOwnerName as String] as? String ?? ""
            if systemUIOwners.contains(owner) {
                continue
            }
            let bounds = windowBounds(win)
            if isFullWindow(width: bounds.width, height: bounds.height) {
                return pid_t(pidNum.int32Value)
            }
        }
        return nil
    }

    private static func sendKeyboardShortcutViaAppleScript(keyCode: Int) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", "tell application \"System Events\" to key code \(keyCode)"]
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()

        let semaphore = DispatchSemaphore(value: 0)
        proc.terminationHandler = { _ in
            semaphore.signal()
        }

        do {
            try proc.run()
        } catch {
            return false
        }

        if semaphore.wait(timeout: .now() + 1.5) == .timedOut {
            proc.terminate()
            return false
        }
        return proc.terminationStatus == 0
    }
}

/// Retains active `NSSound` instances until playback finishes, falling back to `afplay` if needed.
private final class ShutterSoundCoordinator: NSObject, NSSoundDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var activeSounds: Set<ObjectIdentifier> = []
    private var retainedSounds: [ObjectIdentifier: NSSound] = [:]

    func play(path: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let sound = NSSound(contentsOfFile: path, byReference: true) {
                let key = ObjectIdentifier(sound)
                sound.delegate = self
                self.lock.lock()
                self.activeSounds.insert(key)
                self.retainedSounds[key] = sound
                self.lock.unlock()

                if sound.play() {
                    return
                }
                self.releaseSound(key)
            }
            self.playViaAfplay(path: path)
        }
    }

    func sound(_ sound: NSSound, didFinishPlaying flag: Bool) {
        releaseSound(ObjectIdentifier(sound))
    }

    private func releaseSound(_ key: ObjectIdentifier) {
        lock.lock()
        activeSounds.remove(key)
        retainedSounds.removeValue(forKey: key)
        lock.unlock()
    }

    private func playViaAfplay(path: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
        proc.arguments = [path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
    }
}
