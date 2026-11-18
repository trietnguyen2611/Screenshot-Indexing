import Foundation

private extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: Key, default defaultValue: Int) -> Int {
        guard contains(key) else { return defaultValue }
        if (try? decodeNil(forKey: key)) == true { return defaultValue }
        if (try? decode(Bool.self, forKey: key)) != nil { return defaultValue }
        if let intVal = try? decode(Int.self, forKey: key) {
            return intVal
        }
        if let doubleVal = try? decode(Double.self, forKey: key), doubleVal.isFinite {
            return Int(doubleVal.rounded())
        }
        if let strVal = try? decode(String.self, forKey: key) {
            let trimmed = strVal.trimmingCharacters(in: .whitespacesAndNewlines)
            if let doubleVal = Double(trimmed), doubleVal.isFinite {
                return Int(doubleVal.rounded())
            }
        }
        return defaultValue
    }

    func decodeFlexibleBool(forKey key: Key, default defaultValue: Bool) -> Bool {
        guard contains(key) else { return defaultValue }
        if (try? decodeNil(forKey: key)) == true { return defaultValue }
        if let boolVal = try? decode(Bool.self, forKey: key) {
            return boolVal
        }
        if let intVal = try? decode(Int.self, forKey: key) {
            return intVal != 0
        }
        if let doubleVal = try? decode(Double.self, forKey: key), doubleVal.isFinite {
            return doubleVal != 0
        }
        if let strVal = try? decode(String.self, forKey: key) {
            switch strVal.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes", "on":
                return true
            case "false", "0", "no", "off":
                return false
            default:
                return defaultValue
            }
        }
        return defaultValue
    }

    func decodeFlexibleString(forKey key: Key, default defaultValue: String) -> String {
        guard contains(key) else { return defaultValue }
        if (try? decodeNil(forKey: key)) == true { return defaultValue }
        return (try? decode(String.self, forKey: key)) ?? defaultValue
    }
}

public struct CaptureRegion: Codable, Equatable, Hashable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public static let `default` = CaptureRegion(x: 100, y: 100, width: 800, height: 600)

    public init(x: Int = 100, y: Int = 100, width: Int = 800, height: Int = 600) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    private enum CodingKeys: String, CodingKey {
        case x, y, width, height
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let def = CaptureRegion.default
        self.x = container.decodeFlexibleInt(forKey: .x, default: def.x)
        self.y = container.decodeFlexibleInt(forKey: .y, default: def.y)
        self.width = container.decodeFlexibleInt(forKey: .width, default: def.width)
        self.height = container.decodeFlexibleInt(forKey: .height, default: def.height)
    }

    public func normalized() -> CaptureRegion {
        CaptureRegion(
            x: x,
            y: y,
            width: max(10, width),
            height: max(10, height)
        )
    }
}

public enum PageTurnMode: String, Codable, CaseIterable, Sendable {
    case keyboard
    case click
}

public struct PageTurnConfig: Codable, Equatable, Hashable, Sendable {
    public var enabled: Bool
    public var mode: PageTurnMode
    public var keyName: String
    public var keyCode: Int
    public var clickX: Int
    public var clickY: Int

    public static let `default` = PageTurnConfig()

    public init(
        enabled: Bool = true,
        mode: PageTurnMode = .keyboard,
        keyName: String = "ArrowRight",
        keyCode: Int = 124,
        clickX: Int = 500,
        clickY: Int = 500
    ) {
        self.enabled = enabled
        self.mode = mode
        self.keyName = keyName
        self.keyCode = keyCode
        self.clickX = clickX
        self.clickY = clickY
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case mode
        case keyName = "key_name"
        case keyCode = "key_code"
        case clickX = "click_x"
        case clickY = "click_y"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let def = PageTurnConfig.default

        self.enabled = container.decodeFlexibleBool(forKey: .enabled, default: def.enabled)

        let rawMode = container.decodeFlexibleString(forKey: .mode, default: def.mode.rawValue)
        self.mode = PageTurnMode(rawValue: rawMode) ?? def.mode

        let rawKeyName = container.decodeFlexibleString(forKey: .keyName, default: def.keyName)
        if rawKeyName == " " {
            self.keyName = " "
        } else {
            let trimmed = rawKeyName.trimmingCharacters(in: .whitespacesAndNewlines)
            self.keyName = trimmed.isEmpty ? def.keyName : trimmed
        }

        self.keyCode = max(0, container.decodeFlexibleInt(forKey: .keyCode, default: def.keyCode))
        self.clickX = container.decodeFlexibleInt(forKey: .clickX, default: def.clickX)
        self.clickY = container.decodeFlexibleInt(forKey: .clickY, default: def.clickY)
    }

    public func normalized() -> PageTurnConfig {
        let cleanKeyName: String
        if keyName == " " {
            cleanKeyName = " "
        } else {
            let trimmed = keyName.trimmingCharacters(in: .whitespacesAndNewlines)
            cleanKeyName = trimmed.isEmpty ? "ArrowRight" : trimmed
        }
        return PageTurnConfig(
            enabled: enabled,
            mode: mode,
            keyName: cleanKeyName,
            keyCode: max(0, keyCode),
            clickX: clickX,
            clickY: clickY
        )
    }
}

public struct HotkeyShortcut: Codable, Equatable, Hashable, Sendable {
    public var code: String
    public var keycode: Int
    public var ctrl: Bool
    public var shift: Bool
    public var alt: Bool
    public var meta: Bool

    public static let `default` = HotkeyShortcut()

    public init(
        code: String = "KeyR",
        keycode: Int = 15,
        ctrl: Bool = true,
        shift: Bool = true,
        alt: Bool = false,
        meta: Bool = false
    ) {
        self.code = code
        self.keycode = keycode
        self.ctrl = ctrl
        self.shift = shift
        self.alt = alt
        self.meta = meta
    }

    private enum CodingKeys: String, CodingKey {
        case code, keycode, ctrl, shift, alt, meta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let def = HotkeyShortcut.default
        let rawCode = container.decodeFlexibleString(forKey: .code, default: def.code)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.code = rawCode.isEmpty ? def.code : rawCode
        self.keycode = max(0, container.decodeFlexibleInt(forKey: .keycode, default: def.keycode))
        self.ctrl = container.decodeFlexibleBool(forKey: .ctrl, default: def.ctrl)
        self.shift = container.decodeFlexibleBool(forKey: .shift, default: def.shift)
        self.alt = container.decodeFlexibleBool(forKey: .alt, default: def.alt)
        self.meta = container.decodeFlexibleBool(forKey: .meta, default: def.meta)
    }

    public var displayString: String {
        var prefix = ""
        if ctrl { prefix += "⌃" }
        if alt { prefix += "⌥" }
        if shift { prefix += "⇧" }
        if meta { prefix += "⌘" }
        return prefix + Self.keyLabel(for: code)
    }

    public func normalized() -> HotkeyShortcut {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return HotkeyShortcut(
                code: "KeyR",
                keycode: 15,
                ctrl: ctrl,
                shift: shift,
                alt: alt,
                meta: meta
            )
        }
        return HotkeyShortcut(
            code: trimmed,
            keycode: max(0, keycode),
            ctrl: ctrl,
            shift: shift,
            alt: alt,
            meta: meta
        )
    }

    private static func keyLabel(for code: String) -> String {
        if code.hasPrefix("Key"), code.count == 4 {
            return String(code.dropFirst(3)).uppercased()
        }
        if code.hasPrefix("Digit"), code.count == 6 {
            return String(code.dropFirst(5))
        }
        switch code {
        case "Space": return "Space"
        case "Enter": return "↩"
        case "Tab": return "⇥"
        case "Backspace": return "⌫"
        case "Escape": return "⎋"
        case "Equal": return "="
        case "Minus": return "-"
        case "BracketLeft": return "["
        case "BracketRight": return "]"
        case "Quote": return "'"
        case "Semicolon": return ";"
        case "Backslash": return "\\"
        case "Comma": return ","
        case "Slash": return "/"
        case "Period": return "."
        case "Backquote": return "`"
        default: return code
        }
    }
}

public enum AppThemeMode: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
}

public struct AppConfig: Codable, Equatable, Sendable {
    public var saveFolder: String
    public var region: CaptureRegion
    public var intervalSec: Int
    public var maxShots: Int
    public var countdownSec: Int
    public var pageTurn: PageTurnConfig
    public var soundEnabled: Bool
    public var afmEnabled: Bool
    public var notesEnabled: Bool
    public var autoCaptureEnabled: Bool
    public var language: AppLanguage
    public var themeMode: AppThemeMode
    public var notesText: String
    public var overlayShortcut: HotkeyShortcut

    public static let `default` = AppConfig()

    public init(
        saveFolder: String = "",
        region: CaptureRegion = .default,
        intervalSec: Int = 3,
        maxShots: Int = 0,
        countdownSec: Int = 3,
        pageTurn: PageTurnConfig = .default,
        soundEnabled: Bool = true,
        afmEnabled: Bool = true,
        notesEnabled: Bool = true,
        autoCaptureEnabled: Bool = true,
        language: AppLanguage = .en,
        themeMode: AppThemeMode = .system,
        notesText: String = "",
        overlayShortcut: HotkeyShortcut = .default
    ) {
        self.saveFolder = saveFolder
        self.region = region
        self.intervalSec = intervalSec
        self.maxShots = maxShots
        self.countdownSec = countdownSec
        self.pageTurn = pageTurn
        self.soundEnabled = soundEnabled
        self.afmEnabled = afmEnabled
        self.notesEnabled = notesEnabled
        self.autoCaptureEnabled = autoCaptureEnabled
        self.language = language
        self.themeMode = themeMode
        self.notesText = notesText
        self.overlayShortcut = overlayShortcut
    }

    private enum CodingKeys: String, CodingKey {
        case saveFolder = "save_folder"
        case region
        case intervalSec = "interval_sec"
        case maxShots = "max_shots"
        case countdownSec = "countdown_sec"
        case pageTurn = "page_turn"
        case soundEnabled = "sound_enabled"
        case afmEnabled = "afm_enabled"
        case notesEnabled = "notes_enabled"
        case autoCaptureEnabled = "auto_capture_enabled"
        case language
        case themeMode = "theme_mode"
        case notesText = "notes_text"
        case overlayShortcut = "overlay_shortcut"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let def = AppConfig.default

        self.saveFolder = container.decodeFlexibleString(forKey: .saveFolder, default: def.saveFolder)
        self.region = (try? container.decodeIfPresent(CaptureRegion.self, forKey: .region)) ?? def.region
        self.intervalSec = container.decodeFlexibleInt(forKey: .intervalSec, default: def.intervalSec)
        self.maxShots = container.decodeFlexibleInt(forKey: .maxShots, default: def.maxShots)
        self.countdownSec = container.decodeFlexibleInt(forKey: .countdownSec, default: def.countdownSec)
        self.pageTurn = (try? container.decodeIfPresent(PageTurnConfig.self, forKey: .pageTurn)) ?? def.pageTurn
        self.soundEnabled = container.decodeFlexibleBool(forKey: .soundEnabled, default: def.soundEnabled)
        self.afmEnabled = container.decodeFlexibleBool(forKey: .afmEnabled, default: def.afmEnabled)
        self.notesEnabled = container.decodeFlexibleBool(forKey: .notesEnabled, default: def.notesEnabled)
        self.autoCaptureEnabled = container.decodeFlexibleBool(forKey: .autoCaptureEnabled, default: def.autoCaptureEnabled)

        let rawLang = container.decodeFlexibleString(forKey: .language, default: def.language.rawValue)
        self.language = AppLanguage(rawValue: rawLang) ?? def.language

        let rawTheme = container.decodeFlexibleString(forKey: .themeMode, default: def.themeMode.rawValue)
        self.themeMode = AppThemeMode(rawValue: rawTheme) ?? def.themeMode

        self.notesText = container.decodeFlexibleString(forKey: .notesText, default: def.notesText)
        self.overlayShortcut = (try? container.decodeIfPresent(HotkeyShortcut.self, forKey: .overlayShortcut)) ?? def.overlayShortcut
    }

    public func normalized() -> AppConfig {
        let trimmedFolder = saveFolder.trimmingCharacters(in: .whitespacesAndNewlines)
        let expandedFolder = trimmedFolder.isEmpty ? "" : (trimmedFolder as NSString).expandingTildeInPath

        return AppConfig(
            saveFolder: expandedFolder,
            region: region.normalized(),
            intervalSec: min(10, max(1, intervalSec)),
            maxShots: max(0, maxShots),
            countdownSec: min(10, max(0, countdownSec)),
            pageTurn: pageTurn.normalized(),
            soundEnabled: soundEnabled,
            afmEnabled: afmEnabled,
            notesEnabled: notesEnabled,
            autoCaptureEnabled: autoCaptureEnabled,
            language: language,
            themeMode: themeMode,
            notesText: notesText,
            overlayShortcut: overlayShortcut.normalized()
        )
    }
}

public final class ConfigStore: Sendable {
    public static let shared = ConfigStore()

    private let explicitConfigURL: URL?
    private let lock = NSLock()

    public init(configURL: URL? = nil) {
        self.explicitConfigURL = configURL
    }

    public var configURL: URL {
        resolveConfigURL()
    }

    public func load() -> AppConfig {
        lock.lock()
        defer { lock.unlock() }
        return loadUnlocked()
    }

    @discardableResult
    public func save(_ config: AppConfig) throws -> AppConfig {
        lock.lock()
        defer { lock.unlock() }
        return try saveUnlocked(config)
    }

    @discardableResult
    public func update(_ mutate: (inout AppConfig) -> Void) throws -> AppConfig {
        lock.lock()
        defer { lock.unlock() }
        var current = loadUnlocked()
        mutate(&current)
        return try saveUnlocked(current)
    }

    @discardableResult
    public func reset() -> AppConfig {
        lock.lock()
        defer { lock.unlock() }
        let url = resolveConfigURL()
        try? FileManager.default.removeItem(at: url)
        return AppConfig.default
    }

    private func resolveConfigURL() -> URL {
        if let explicitConfigURL {
            return explicitConfigURL
        }
        if let envOverride = ProcessInfo.processInfo.environment["SCREENSHOT_INDEXING_CONFIG_PATH"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !envOverride.isEmpty {
            let expanded = (envOverride as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("Screenshot Indexing", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
    }

    private func loadUnlocked() -> AppConfig {
        let url = resolveConfigURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return AppConfig.default.normalized()
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
            return decoded.normalized()
        } catch {
            return AppConfig.default.normalized()
        }
    }

    private func saveUnlocked(_ config: AppConfig) throws -> AppConfig {
        let normalized = config.normalized()
        let url = resolveConfigURL()
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(normalized)
        data.append(0x0A) // Trailing newline
        try data.write(to: url, options: [.atomic])
        return normalized
    }
}
