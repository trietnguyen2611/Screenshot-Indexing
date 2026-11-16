import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Observation
import ScreenCaptureKit
import UniformTypeIdentifiers

/// Logical bounds of the main display in Quartz screen points.
struct DisplayInfo: Equatable, Sendable {
    let originX: Int
    let originY: Int
    let screenWidth: Int
    let screenHeight: Int
}

/// Full-screen temporary preview image and display coordinate scaling metadata.
struct ScreenPreviewResult: Sendable {
    let image: NSImage
    let previewURL: URL
    let screenWidth: Int
    let screenHeight: Int
    let imageWidth: Int
    let imageHeight: Int
    let scaleFactor: Double
    let originX: Int
    let originY: Int
}

/// Lifecycle phase of an automated timed screen-capture session.
enum CapturePhase: String, Equatable, Sendable {
    case idle
    case countdown
    case capturing
    case completed
    case stopped
    case error
}

/// Immutable status snapshot exposed by `CaptureController` for the SwiftUI Auto Capture tab.
struct CaptureStatusSnapshot: Equatable, Sendable {
    var running: Bool
    var phase: CapturePhase
    var countdownRemaining: Int
    var capturedCount: Int
    var maxShots: Int
    var intervalSec: Int
    var saveFolder: String
    var lastFile: String?
    var capturedFiles: [String]
    var lastError: String?

    static let idle = CaptureStatusSnapshot(
        running: false,
        phase: .idle,
        countdownRemaining: 0,
        capturedCount: 0,
        maxShots: 0,
        intervalSec: 3,
        saveFolder: "",
        lastFile: nil,
        capturedFiles: [],
        lastError: nil
    )
}

/// Errors returned by screen capture helpers and `CaptureController`.
enum ScreenCaptureError: LocalizedError, Equatable, Sendable {
    case alreadyRunning
    case missingSaveFolder
    case invalidRegion
    case captureFailed(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Capture session is already running."
        case .missingSaveFolder:
            return "Save folder is required."
        case .invalidRegion:
            return "Invalid capture region dimensions."
        case .captureFailed(let message):
            return message
        }
    }
}

/// Stateless screen capture utilities (display metrics, collision-free naming, preview & region capture).
enum ScreenCaptureHelper {
    private static let previewFilename = "screenshot_indexing_preview.png"

    private static var previewFileURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(previewFilename)
    }

    /// Query main display logical bounds in Quartz screen points.
    static func mainDisplayInfo() -> DisplayInfo {
        let bounds = CGDisplayBounds(CGMainDisplayID())
        let width = max(1, Int(bounds.size.width.rounded()))
        let height = max(1, Int(bounds.size.height.rounded()))
        return DisplayInfo(
            originX: Int(bounds.origin.x.rounded()),
            originY: Int(bounds.origin.y.rounded()),
            screenWidth: width,
            screenHeight: height
        )
    }

    /// Generate a collision-free macOS-compatible screenshot filename matching `FileIndexingService`.
    static func generateScreenshotFilename(in folder: String, now: Date = Date()) -> String {
        let fm = FileManager.default
        let folderURL = URL(fileURLWithPath: folder, isDirectory: true)
        let calendar = Calendar.current

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH.mm.ss"

        // Advance +1s within the same date first so chronological sort keys stay strictly increasing.
        for offset in 0..<60 {
            guard let candidateDate = calendar.date(byAdding: .second, value: offset, to: now),
                  calendar.isDate(candidateDate, inSameDayAs: now) else {
                break
            }
            let candidate = "Screenshot \(dateFormatter.string(from: candidateDate)) at \(timeFormatter.string(from: candidateDate)).png"
            if !fm.fileExists(atPath: folderURL.appendingPathComponent(candidate).path) {
                return candidate
            }
        }

        let dateStr = dateFormatter.string(from: now)
        let timeStr = timeFormatter.string(from: now)
        var counter = 2
        while true {
            let candidate = "Screenshot \(dateStr) (\(counter)) at \(timeStr).png"
            if !fm.fileExists(atPath: folderURL.appendingPathComponent(candidate).path) {
                return candidate
            }
            counter += 1
        }
    }

    /// Capture a full-screen temporary PNG preview and display Retina scale metadata.
    static func captureFullscreenPreview(delaySec: Double = 0.2) async throws -> ScreenPreviewResult {
        let clampedDelay = max(0.0, min(5.0, delaySec))
        if clampedDelay > 0.0 {
            try await Task.sleep(for: .seconds(clampedDelay))
        }

        let targetURL = previewFileURL
        let display = mainDisplayInfo()
        let displayBounds = CGDisplayBounds(CGMainDisplayID())

        try await Task.detached(priority: .userInitiated) {
            try captureToPNG(
                outputURL: targetURL,
                screencaptureArgs: ["-x", targetURL.path],
                fallbackRect: displayBounds
            )
        }.value

        guard let image = NSImage(contentsOf: targetURL) else {
            throw ScreenCaptureError.captureFailed("Failed to decode preview screenshot.")
        }

        let (imageWidth, imageHeight) = readPNGPixelDimensions(at: targetURL, fallbackImage: image)
        let rawScale = Double(imageWidth) / Double(max(1, display.screenWidth))
        let scaleFactor = (rawScale * 10_000.0).rounded() / 10_000.0

        return ScreenPreviewResult(
            image: image,
            previewURL: targetURL,
            screenWidth: display.screenWidth,
            screenHeight: display.screenHeight,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            scaleFactor: scaleFactor,
            originX: display.originX,
            originY: display.originY
        )
    }

    /// Capture a single fixed logical screen region into `saveFolder`.
    static func captureRegionOnce(
        saveFolder: String,
        region: CaptureRegion,
        soundEnabled: Bool
    ) -> Result<(filename: String, url: URL), Error> {
        let expandedFolder = (saveFolder.trimmingCharacters(in: .whitespacesAndNewlines) as NSString)
            .expandingTildeInPath
        guard !expandedFolder.isEmpty else {
            return .failure(ScreenCaptureError.missingSaveFolder)
        }
        guard region.width > 0, region.height > 0 else {
            return .failure(ScreenCaptureError.invalidRegion)
        }

        do {
            try FileManager.default.createDirectory(
                atPath: expandedFolder,
                withIntermediateDirectories: true
            )
        } catch {
            return .failure(error)
        }

        let filename = generateScreenshotFilename(in: expandedFolder)
        let outputURL = URL(fileURLWithPath: expandedFolder, isDirectory: true)
            .appendingPathComponent(filename)
        let regionArg = "\(region.x),\(region.y),\(region.width),\(region.height)"
        let fallbackRect = CGRect(
            x: region.x,
            y: region.y,
            width: region.width,
            height: region.height
        )

        do {
            try captureToPNG(
                outputURL: outputURL,
                screencaptureArgs: ["-x", "-R", regionArg, outputURL.path],
                fallbackRect: fallbackRect
            )
        } catch {
            return .failure(error)
        }

        InputSimulationService.playShutterSound(enabled: soundEnabled)
        return .success((filename: filename, url: outputURL))
    }

    /// Remove the temporary full-screen preview PNG if present.
    static func cleanupPreviewFile() {
        let path = previewFileURL.path
        if FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    // MARK: - Private Capture & PNG Helpers

    private static func captureToPNG(
        outputURL: URL,
        screencaptureArgs: [String],
        fallbackRect: CGRect
    ) throws {
        let primaryResult = runScreencaptureCLI(arguments: screencaptureArgs, outputURL: outputURL)
        if primaryResult.success {
            return
        }

        if captureWithScreenCaptureKit(rect: fallbackRect, outputURL: outputURL) {
            return
        }

        removeEmptyFileIfNeeded(at: outputURL)
        throw ScreenCaptureError.captureFailed(primaryResult.errorMessage ?? "Screen capture failed")
    }

    private static func runScreencaptureCLI(
        arguments: [String],
        outputURL: URL
    ) -> (success: Bool, errorMessage: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments

        let stderrPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            semaphore.signal()
        }

        do {
            try process.run()
        } catch {
            return (false, error.localizedDescription)
        }

        if semaphore.wait(timeout: .now() + 15.0) == .timedOut {
            process.terminate()
            return (false, "screencapture timed out")
        }

        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let errText = String(data: errData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if process.terminationStatus == 0 && isNonEmptyFile(at: outputURL) {
            return (true, nil)
        }

        removeEmptyFileIfNeeded(at: outputURL)
        return (false, (errText?.isEmpty == false) ? errText : "Screen capture failed")
    }

    private static func captureWithScreenCaptureKit(rect: CGRect, outputURL: URL) -> Bool {
        final class ImageBox: @unchecked Sendable {
            private let lock = NSLock()
            private var value: CGImage?

            func set(_ image: CGImage?) {
                lock.lock()
                value = image
                lock.unlock()
            }

            func get() -> CGImage? {
                lock.lock()
                defer { lock.unlock() }
                return value
            }
        }

        let semaphore = DispatchSemaphore(value: 0)
        let imageBox = ImageBox()

        SCScreenshotManager.captureImage(in: rect) { image, _ in
            imageBox.set(image)
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + 10.0) == .timedOut {
            return false
        }

        guard let cgImage = imageBox.get() else {
            return false
        }

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return false
        }

        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            return false
        }

        return isNonEmptyFile(at: outputURL)
    }

    private static func isNonEmptyFile(at url: URL) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber else {
            return false
        }
        return size.int64Value > 0
    }

    private static func removeEmptyFileIfNeeded(at url: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber,
              size.int64Value == 0 else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    private static func readPNGPixelDimensions(at url: URL, fallbackImage: NSImage) -> (Int, Int) {
        if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
           let pw = props[kCGImagePropertyPixelWidth] as? NSNumber,
           let ph = props[kCGImagePropertyPixelHeight] as? NSNumber,
           pw.intValue > 0,
           ph.intValue > 0 {
            return (pw.intValue, ph.intValue)
        }

        if let fh = try? FileHandle(forReadingFrom: url) {
            defer { try? fh.close() }
            if let header = try? fh.read(upToCount: 24),
               header.count == 24,
               header[0..<8] == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
               header[12..<16] == Data("IHDR".utf8) {
                let w = header.subdata(in: 16..<20).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                let h = header.subdata(in: 20..<24).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                if w > 0 && h > 0 {
                    return (Int(w), Int(h))
                }
            }
        }

        let rep = fallbackImage.representations.first
        let w = max(1, rep?.pixelsWide ?? Int(fallbackImage.size.width.rounded()))
        let h = max(1, rep?.pixelsHigh ?? Int(fallbackImage.size.height.rounded()))
        return (w, h)
    }
}

/// Observable MainActor controller managing timed auto-capture & page-turn loops.
@MainActor
@Observable
final class CaptureController {
    static let shared = CaptureController()

    private(set) var status: CaptureStatusSnapshot = .idle
    private(set) var lastCapturedImageURL: URL?

    private var captureTask: Task<Void, Never>?
    private var activeSessionID: UUID?

    private init() {}

    /// Validate configuration and begin the timed countdown + capture + page-turn loop.
    @discardableResult
    func start(
        config: AppConfig,
        onShot: (@MainActor (String, String) -> Void)? = nil
    ) -> Result<Void, Error> {
        if status.running {
            return .failure(ScreenCaptureError.alreadyRunning)
        }

        let rawFolder = config.saveFolder.trimmingCharacters(in: .whitespacesAndNewlines)
        let saveFolder = (rawFolder as NSString).expandingTildeInPath
        guard !saveFolder.isEmpty else {
            return .failure(ScreenCaptureError.missingSaveFolder)
        }

        do {
            try FileManager.default.createDirectory(
                atPath: saveFolder,
                withIntermediateDirectories: true
            )
        } catch {
            return .failure(error)
        }

        let region = config.region
        guard region.width >= 10, region.height >= 10 else {
            return .failure(ScreenCaptureError.invalidRegion)
        }

        let intervalSec = max(1, min(10, config.intervalSec))
        let countdownSec = max(0, min(10, config.countdownSec))
        let maxShots = max(0, config.maxShots)
        let soundEnabled = config.soundEnabled
        let pageTurn = config.pageTurn

        let sessionID = UUID()
        activeSessionID = sessionID
        lastCapturedImageURL = nil

        status = CaptureStatusSnapshot(
            running: true,
            phase: countdownSec > 0 ? .countdown : .capturing,
            countdownRemaining: countdownSec,
            capturedCount: 0,
            maxShots: maxShots,
            intervalSec: intervalSec,
            saveFolder: saveFolder,
            lastFile: nil,
            capturedFiles: [],
            lastError: nil
        )

        captureTask = Task { [weak self] in
            guard let self else { return }
            await self.runCaptureLoop(
                sessionID: sessionID,
                saveFolder: saveFolder,
                region: region,
                intervalSec: intervalSec,
                countdownSec: countdownSec,
                maxShots: maxShots,
                soundEnabled: soundEnabled,
                pageTurn: pageTurn,
                onShot: onShot
            )
        }

        return .success(())
    }

    /// Abort any active capture session immediately.
    func stop() {
        let wasRunning = status.running
        activeSessionID = nil
        captureTask?.cancel()
        captureTask = nil

        status.running = false
        status.countdownRemaining = 0
        if (wasRunning || status.phase == .countdown || status.phase == .capturing)
            && status.phase != .completed
            && status.phase != .error {
            status.phase = .stopped
        }
    }

    /// Stop any active session and restore initial idle state.
    func reset() {
        stop()
        lastCapturedImageURL = nil
        status = .idle
    }

    // MARK: - Capture Loop

    private func runCaptureLoop(
        sessionID: UUID,
        saveFolder: String,
        region: CaptureRegion,
        intervalSec: Int,
        countdownSec: Int,
        maxShots: Int,
        soundEnabled: Bool,
        pageTurn: PageTurnConfig,
        onShot: (@MainActor (String, String) -> Void)?
    ) async {
        do {
            let initialTargetPID = await Task.detached(priority: .userInitiated) {
                InputSimulationService.findTargetPID(for: region)
            }.value

            for remaining in stride(from: countdownSec, through: 1, by: -1) {
                try Task.checkCancellation()
                guard activeSessionID == sessionID else { return }
                status.phase = .countdown
                status.countdownRemaining = remaining
                try await Task.sleep(for: .seconds(1))
            }

            try Task.checkCancellation()
            guard activeSessionID == sessionID else { return }

            status.countdownRemaining = 0
            status.phase = .capturing

            var targetPID = await Task.detached(priority: .userInitiated) {
                InputSimulationService.findTargetPID(for: region) ?? initialTargetPID
            }.value

            if let pid = targetPID {
                _ = await Task.detached(priority: .userInitiated) {
                    InputSimulationService.activateTargetApp(pid: pid)
                }.value
            }

            while !Task.isCancelled && activeSessionID == sessionID {
                let shotResult = await Task.detached(priority: .userInitiated) {
                    ScreenCaptureHelper.captureRegionOnce(
                        saveFolder: saveFolder,
                        region: region,
                        soundEnabled: soundEnabled
                    )
                }.value

                guard !Task.isCancelled && activeSessionID == sessionID else { return }

                switch shotResult {
                case .failure(let error):
                    status.lastError = error.localizedDescription
                    status.phase = .error
                    status.running = false
                    captureTask = nil
                    return

                case .success(let (filename, url)):
                    status.capturedCount += 1
                    status.lastFile = filename
                    status.capturedFiles.append(filename)
                    lastCapturedImageURL = url
                    onShot?(saveFolder, filename)
                }

                if maxShots > 0 && status.capturedCount >= maxShots {
                    status.phase = .completed
                    status.running = false
                    captureTask = nil
                    return
                }

                try Task.checkCancellation()
                guard activeSessionID == sessionID else { return }

                if pageTurn.enabled {
                    let existingPID = targetPID
                    let (nextPID, turned) = await Task.detached(priority: .userInitiated) {
                        let loopTarget = InputSimulationService.findTargetPID(for: region) ?? existingPID
                        let ok = InputSimulationService.triggerPageTurn(
                            config: pageTurn,
                            targetPID: loopTarget
                        )
                        return (loopTarget, ok)
                    }.value

                    guard !Task.isCancelled && activeSessionID == sessionID else { return }
                    if let nextPID {
                        targetPID = nextPID
                    }
                    if !turned && status.lastError == nil {
                        status.lastError = "Auto page-turn blocked: grant Accessibility permission in System Settings"
                    }
                }

                try await Task.sleep(for: .seconds(Double(intervalSec)))
            }
        } catch is CancellationError {
            // Handled cleanly in stop()/reset() or below if cancelled externally.
        } catch {
            if activeSessionID == sessionID {
                status.lastError = error.localizedDescription
                status.phase = .error
                status.running = false
                captureTask = nil
            }
            return
        }

        if activeSessionID == sessionID {
            status.running = false
            status.countdownRemaining = 0
            if status.phase != .completed && status.phase != .error {
                status.phase = .stopped
            }
            captureTask = nil
        }
    }
}
