import Foundation
import XCTest
@testable import ScreenshotIndexing

final class ScreenshotIndexingTests: XCTestCase {
    private var tempDirectories: [URL] = []

    override func tearDownWithError() throws {
        let fm = FileManager.default
        for dir in tempDirectories {
            try? fm.removeItem(at: dir)
        }
        tempDirectories.removeAll()
        try super.tearDownWithError()
    }

    private func makeTempDirectory(name: String = UUID().uuidString) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenshotIndexingTests-\(name)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDirectories.append(dir)
        return dir
    }

    // MARK: - FileIndexingService: Screenshot Detection

    func testIsScreenshotFileSupportsEnglishAndVietnameseNFCAndNFD() {
        let english = "Screenshot 2026-01-01 at 10.00.00.png"
        let englishUppercaseExt = "Screenshot 2026-01-01 at 10.00.00.PNG"
        let vietnameseBase = "Ảnh màn hình 2026-01-01 lúc 10.00.00.png"
        let vietnameseNFC = vietnameseBase.precomposedStringWithCanonicalMapping
        let vietnameseNFD = vietnameseBase.decomposedStringWithCanonicalMapping
        let vietnameseUnaccented = "anh man hinh 2026-01-01 luc 10.00.00.png"

        XCTAssertTrue(FileIndexingService.isScreenshotFile(english))
        XCTAssertTrue(FileIndexingService.isScreenshotFile(englishUppercaseExt))
        XCTAssertTrue(FileIndexingService.isScreenshotFile(vietnameseNFC))
        XCTAssertTrue(FileIndexingService.isScreenshotFile(vietnameseNFD))
        XCTAssertTrue(FileIndexingService.isScreenshotFile(vietnameseUnaccented))

        XCTAssertFalse(FileIndexingService.isScreenshotFile("Screenshot 2026-01-01 at 10.00.00.jpg"))
        XCTAssertFalse(FileIndexingService.isScreenshotFile("Screenshot 2026-01-01 at 10.00.00.webp"))
        XCTAssertFalse(FileIndexingService.isScreenshotFile("photo_10.00.00.png"))
        XCTAssertFalse(FileIndexingService.isScreenshotFile("1.png"))
        XCTAssertFalse(FileIndexingService.isScreenshotFile("notes.txt"))
    }

    // MARK: - FileIndexingService: Sort Key, Seconds Display & Chronological Scan

    func testSortKeyAndSecondsDisplay() {
        XCTAssertEqual(
            FileIndexingService.sortKey(for: "Screenshot 2026-01-01 at 10.05.09.png"),
            10 * 3600 + 5 * 60 + 9
        )
        XCTAssertEqual(
            FileIndexingService.sortKey(for: "Ảnh màn hình 2026-01-01 lúc 00.01.02.png"),
            62
        )
        XCTAssertEqual(
            FileIndexingService.sortKey(for: "Screenshot without timestamp.png"),
            0
        )

        XCTAssertEqual(
            FileIndexingService.secondsDisplay(for: "Screenshot 2026-01-01 at 10.05.09.png"),
            "09"
        )
        XCTAssertEqual(
            FileIndexingService.secondsDisplay(for: "Screenshot without timestamp.png"),
            "?"
        )
    }

    func testScanFolderChronologicalOrderingAndFiltering() throws {
        let dir = try makeTempDirectory()
        let fm = FileManager.default

        let name3 = "Screenshot 2026-11-14 at 10.00.03.png"
        let name1NFC = "Ảnh màn hình 2026-11-14 lúc 10.00.01.png".precomposedStringWithCanonicalMapping
        let name2NFD = "Ảnh màn hình 2026-11-14 lúc 10.00.02.png".decomposedStringWithCanonicalMapping
        let name4 = "anh man hinh 2026-11-14 luc 10.00.04.png"
        let ignoredPNG = "photo_10.00.05.png"
        let ignoredJPG = "Screenshot 2026-11-14 at 10.00.06.jpg"

        let dummyData = Data("png-placeholder".utf8)
        for fname in [name3, name1NFC, name2NFD, name4, ignoredPNG, ignoredJPG] {
            fm.createFile(atPath: dir.appendingPathComponent(fname).path, contents: dummyData)
        }

        let items = try FileIndexingService.scanFolder(at: dir.path)
        XCTAssertEqual(items.count, 4)

        let returnedNFCNames = items.map { $0.name.precomposedStringWithCanonicalMapping }
        XCTAssertEqual(
            returnedNFCNames,
            [
                name1NFC.precomposedStringWithCanonicalMapping,
                name2NFD.precomposedStringWithCanonicalMapping,
                name3,
                name4,
            ]
        )

        XCTAssertEqual(items.map(\.secondsDisplay), ["01", "02", "03", "04"])
        XCTAssertTrue(zip(items, items.dropFirst()).allSatisfy { $0.sortKey <= $1.sortKey })

        XCTAssertThrowsError(try FileIndexingService.scanFolder(at: dir.appendingPathComponent("missing").path)) { error in
            XCTAssertEqual(error as? FileIndexingError, .folderNotExist)
        }
    }

    // MARK: - FileIndexingService: Preview Names & Safe Two-Step Rename

    func testApplyPreviewNamesAndSafeTwoStepRename() throws {
        let dir = try makeTempDirectory()
        let fm = FileManager.default

        let f1 = "Screenshot 2026-11-14 at 09.00.01.png"
        let f2 = "Screenshot 2026-11-14 at 09.00.02.png"
        let f3 = "Screenshot 2026-11-14 at 09.00.03.png"
        fm.createFile(atPath: dir.appendingPathComponent(f1).path, contents: Data("first".utf8))
        fm.createFile(atPath: dir.appendingPathComponent(f2).path, contents: Data("second".utf8))
        fm.createFile(atPath: dir.appendingPathComponent(f3).path, contents: Data("third".utf8))

        // Pre-existing target "2.png" must NOT be overwritten during step 2.
        fm.createFile(atPath: dir.appendingPathComponent("2.png").path, contents: Data("do-not-overwrite".utf8))

        let scanned = try FileIndexingService.scanFolder(at: dir.path)
        XCTAssertEqual(scanned.count, 3)

        let previewed = try FileIndexingService.applyPreviewNames(to: scanned, start: 1, end: 2)
        XCTAssertEqual(previewed[0].previewNewName, "1.png")
        XCTAssertEqual(previewed[1].previewNewName, "2.png")
        XCTAssertNil(previewed[2].previewNewName)

        XCTAssertThrowsError(try FileIndexingService.applyPreviewNames(to: scanned, start: -1, end: 2)) { error in
            XCTAssertEqual(error as? FileIndexingError, .invalidRange)
        }
        XCTAssertThrowsError(try FileIndexingService.applyPreviewNames(to: scanned, start: 5, end: 2)) { error in
            XCTAssertEqual(error as? FileIndexingError, .invalidRange)
        }

        let result = try FileIndexingService.renameFiles(in: dir.path, items: scanned, start: 1, end: 2)
        XCTAssertEqual(result.totalCount, 2)
        XCTAssertEqual(result.successCount, 1)

        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("1.png")), Data("first".utf8))
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("2.png")), Data("do-not-overwrite".utf8))
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(f3)), Data("third".utf8))

        let remainingFiles = try fm.contentsOfDirectory(atPath: dir.path)
        XCTAssertFalse(remainingFiles.contains { $0.hasPrefix("__temp_rename_") })
    }

    func testTwoStepRenameHandlesNonOverlappingBatchCleanly() throws {
        let dir = try makeTempDirectory()
        let fm = FileManager.default

        let f1 = "Screenshot 2026-11-14 at 08.00.01.png"
        let f2 = "Screenshot 2026-11-14 at 08.00.02.png"
        fm.createFile(atPath: dir.appendingPathComponent(f1).path, contents: Data("alpha".utf8))
        fm.createFile(atPath: dir.appendingPathComponent(f2).path, contents: Data("beta".utf8))

        let scanned = try FileIndexingService.scanFolder(at: dir.path)
        let result = try FileIndexingService.renameFiles(in: dir.path, items: scanned, start: 10, end: 11)
        XCTAssertEqual(result.totalCount, 2)
        XCTAssertEqual(result.successCount, 2)

        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("10.png")), Data("alpha".utf8))
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("11.png")), Data("beta".utf8))
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent(f1).path))
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent(f2).path))

        let remainingFiles = try fm.contentsOfDirectory(atPath: dir.path)
        XCTAssertFalse(remainingFiles.contains { $0.hasPrefix("__temp_rename_") })
    }

    // MARK: - AppConfig & ConfigStore

    func testAppConfigNormalizationAndClamping() {
        var config = AppConfig()
        config.saveFolder = "~/Desktop"
        config.intervalSec = 99
        config.countdownSec = -4
        config.maxShots = -10
        config.region = CaptureRegion(x: 10, y: 20, width: 3, height: -8)

        let upperNormalized = config.normalized()
        XCTAssertEqual(upperNormalized.intervalSec, 10)
        XCTAssertEqual(upperNormalized.countdownSec, 0)
        XCTAssertEqual(upperNormalized.maxShots, 0)
        XCTAssertEqual(upperNormalized.region, CaptureRegion(x: 10, y: 20, width: 10, height: 10))
        XCTAssertFalse(upperNormalized.saveFolder.hasPrefix("~"))

        config.intervalSec = 0
        config.countdownSec = 42
        let lowerNormalized = config.normalized()
        XCTAssertEqual(lowerNormalized.intervalSec, 1)
        XCTAssertEqual(lowerNormalized.countdownSec, 10)
    }

    func testConfigStoreAtomicSaveLoadUpdateAndReset() throws {
        let dir = try makeTempDirectory()
        let configURL = dir.appendingPathComponent("nested/app_support/config.json")
        let store = ConfigStore(configURL: configURL)

        let initial = store.load()
        XCTAssertEqual(initial.intervalSec, 3)
        XCTAssertEqual(initial.countdownSec, 3)
        XCTAssertEqual(initial.region, .default)

        var custom = initial
        custom.saveFolder = dir.path
        custom.intervalSec = 25
        custom.countdownSec = 15
        custom.maxShots = 12
        custom.region = CaptureRegion(x: 50, y: 60, width: 4, height: 500)
        custom.language = .vi
        custom.themeMode = .dark
        custom.notesText = "Meeting notes"
        custom.soundEnabled = false

        let saved = try store.save(custom)
        XCTAssertEqual(saved.intervalSec, 10)
        XCTAssertEqual(saved.countdownSec, 10)
        XCTAssertEqual(saved.region.width, 10)
        XCTAssertEqual(saved.region.height, 500)
        XCTAssertTrue(FileManager.default.fileExists(atPath: configURL.path))

        let reloaded = store.load()
        XCTAssertEqual(reloaded, saved)

        let updated = try store.update { cfg in
            cfg.intervalSec = 0
            cfg.afmEnabled = false
        }
        XCTAssertEqual(updated.intervalSec, 1)
        XCTAssertFalse(updated.afmEnabled)
        XCTAssertEqual(store.load().intervalSec, 1)

        let resetConfig = store.reset()
        XCTAssertEqual(resetConfig.intervalSec, 3)
        XCTAssertEqual(resetConfig.countdownSec, 3)
        XCTAssertEqual(resetConfig.region, .default)
        XCTAssertTrue(resetConfig.afmEnabled)
    }

    func testAppConfigResilientDecodingDefaultsMissingKeys() throws {
        let partialJSON = Data(#"{"interval_sec": 99, "language": "vi"}"#.utf8)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: partialJSON).normalized()
        XCTAssertEqual(decoded.intervalSec, 10)
        XCTAssertEqual(decoded.language, .vi)
        XCTAssertEqual(decoded.countdownSec, 3)
        XCTAssertEqual(decoded.region, .default)
        XCTAssertTrue(decoded.soundEnabled)
    }

    // MARK: - InputSimulationService

    func testInputSimulationResolveKeyCode() {
        XCTAssertEqual(InputSimulationService.resolveKeyCode(keyName: "ArrowRight"), 124)
        XCTAssertEqual(InputSimulationService.resolveKeyCode(keyName: "arrowright"), 124)
        XCTAssertEqual(InputSimulationService.resolveKeyCode(keyName: "ARROWLEFT"), 123)
        XCTAssertEqual(InputSimulationService.resolveKeyCode(keyName: "Space"), 49)
        XCTAssertEqual(InputSimulationService.resolveKeyCode(keyName: "space"), 49)
        XCTAssertEqual(InputSimulationService.resolveKeyCode(keyName: " "), 49)
        XCTAssertEqual(InputSimulationService.resolveKeyCode(keyName: "f5"), 96)
        XCTAssertEqual(InputSimulationService.resolveKeyCode(keyName: "UnknownKey", keyCode: 36), 36)
        XCTAssertEqual(InputSimulationService.resolveKeyCode(keyName: "UnknownKey", keyCode: nil), 124)
        XCTAssertEqual(InputSimulationService.resolveKeyCode(keyName: "", keyCode: -1), 124)
    }

    // MARK: - ScreenCaptureHelper

    func testGenerateScreenshotFilenameAvoidsCollisions() throws {
        let dir = try makeTempDirectory()
        let fm = FileManager.default
        let fixedDate = try XCTUnwrap(
            Calendar.current.date(
                from: DateComponents(year: 2026, month: 1, day: 1, hour: 10, minute: 0, second: 0)
            )
        )

        let firstName = ScreenCaptureHelper.generateScreenshotFilename(in: dir.path, now: fixedDate)
        XCTAssertTrue(FileIndexingService.isScreenshotFile(firstName))
        XCTAssertEqual(FileIndexingService.sortKey(for: firstName), 10 * 3600)

        fm.createFile(atPath: dir.appendingPathComponent(firstName).path, contents: Data())

        let secondName = ScreenCaptureHelper.generateScreenshotFilename(in: dir.path, now: fixedDate)
        XCTAssertNotEqual(firstName, secondName)
        XCTAssertTrue(FileIndexingService.isScreenshotFile(secondName))
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent(secondName).path))
        XCTAssertEqual(FileIndexingService.sortKey(for: secondName), 10 * 3600 + 1)
    }
}
