import AppKit
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

    func testRenameFilesSucceedsWhenStaleTempRenameFileExists() throws {
        let dir = try makeTempDirectory()
        let fm = FileManager.default

        let f1 = "Screenshot 2026-11-14 at 07.00.01.png"
        let f2 = "Screenshot 2026-11-14 at 07.00.02.png"
        let staleTemp = "__temp_rename_1.png"
        fm.createFile(atPath: dir.appendingPathComponent(f1).path, contents: Data("one".utf8))
        fm.createFile(atPath: dir.appendingPathComponent(f2).path, contents: Data("two".utf8))
        fm.createFile(atPath: dir.appendingPathComponent(staleTemp).path, contents: Data("stale".utf8))

        let scanned = try FileIndexingService.scanFolder(at: dir.path)
        XCTAssertEqual(scanned.count, 2)

        let result = try FileIndexingService.renameFiles(in: dir.path, items: scanned, start: 1, end: 2)
        XCTAssertEqual(result.totalCount, 2)
        XCTAssertEqual(result.successCount, 2)

        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("1.png")), Data("one".utf8))
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("2.png")), Data("two".utf8))
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(staleTemp)), Data("stale".utf8))
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent(f1).path))
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent(f2).path))

        let remainingTempFiles = try fm.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix("__temp_rename_") }
        XCTAssertEqual(remainingTempFiles, [staleTemp])
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

    func testShortcutMetadataRejectsShiftOnlyAndAllowsPrimaryModifiersAndFunctionKeys() throws {
        let shiftOnlyEvent = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.shift],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "A",
                charactersIgnoringModifiers: "a",
                isARepeat: false,
                keyCode: 0
            )
        )
        XCTAssertNil(InputSimulationService.shortcutMetadata(from: shiftOnlyEvent))

        let ctrlShiftEvent = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.control, .shift],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "R",
                charactersIgnoringModifiers: "r",
                isARepeat: false,
                keyCode: 15
            )
        )
        let shortcut = try XCTUnwrap(InputSimulationService.shortcutMetadata(from: ctrlShiftEvent))
        XCTAssertEqual(shortcut, HotkeyShortcut(code: "KeyR", keycode: 15, ctrl: true, shift: true, alt: false, meta: false))

        let f5Event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: 96
            )
        )
        let fnShortcut = try XCTUnwrap(InputSimulationService.shortcutMetadata(from: f5Event))
        XCTAssertEqual(fnShortcut, HotkeyShortcut(code: "F5", keycode: 96, ctrl: false, shift: false, alt: false, meta: false))
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

    func testCaptureRegionOnceRejectsRegionsSmallerThan10x10() throws {
        let dir = try makeTempDirectory()

        let narrowResult = ScreenCaptureHelper.captureRegionOnce(
            saveFolder: dir.path,
            region: CaptureRegion(x: 100, y: 100, width: 9, height: 100),
            soundEnabled: false
        )
        switch narrowResult {
        case .success:
            XCTFail("Expected captureRegionOnce to fail when width < 10")
        case .failure(let error):
            XCTAssertEqual(error as? ScreenCaptureError, .invalidRegion)
        }

        let shortResult = ScreenCaptureHelper.captureRegionOnce(
            saveFolder: dir.path,
            region: CaptureRegion(x: 100, y: 100, width: 100, height: 9),
            soundEnabled: false
        )
        switch shortResult {
        case .success:
            XCTFail("Expected captureRegionOnce to fail when height < 10")
        case .failure(let error):
            XCTAssertEqual(error as? ScreenCaptureError, .invalidRegion)
        }
    }

    // MARK: - FileIndexingService: Edge Cases & Rollback

    func testApplyPreviewNamesPartialRangeAndInvalidInputs() throws {
        let dir = try makeTempDirectory()
        let items = [
            ScreenshotItem(
                index: 1,
                name: "Screenshot 2026-11-14 at 10.00.01.png",
                url: dir.appendingPathComponent("Screenshot 2026-11-14 at 10.00.01.png"),
                secondsDisplay: "01",
                sortKey: 36001
            ),
            ScreenshotItem(
                index: 2,
                name: "Screenshot 2026-11-14 at 10.00.02.png",
                url: dir.appendingPathComponent("Screenshot 2026-11-14 at 10.00.02.png"),
                secondsDisplay: "02",
                sortKey: 36002
            ),
            ScreenshotItem(
                index: 3,
                name: "Screenshot 2026-11-14 at 10.00.03.png",
                url: dir.appendingPathComponent("Screenshot 2026-11-14 at 10.00.03.png"),
                secondsDisplay: "03",
                sortKey: 36003
            ),
            ScreenshotItem(
                index: 4,
                name: "Screenshot 2026-11-14 at 10.00.04.png",
                url: dir.appendingPathComponent("Screenshot 2026-11-14 at 10.00.04.png"),
                secondsDisplay: "04",
                sortKey: 36004
            ),
        ]

        let partial = try FileIndexingService.applyPreviewNames(to: items, start: 7, end: 8)
        XCTAssertEqual(partial.map(\.previewNewName), ["7.png", "8.png", nil, nil])

        let zeroBasedSingle = try FileIndexingService.applyPreviewNames(to: items, start: 0, end: 0)
        XCTAssertEqual(zeroBasedSingle.map(\.previewNewName), ["0.png", nil, nil, nil])

        let oversizedRange = try FileIndexingService.applyPreviewNames(to: items, start: 10, end: 99)
        XCTAssertEqual(oversizedRange.map(\.previewNewName), ["10.png", "11.png", "12.png", "13.png"])

        let emptyResult = try FileIndexingService.applyPreviewNames(to: [], start: 1, end: 3)
        XCTAssertTrue(emptyResult.isEmpty)

        XCTAssertThrowsError(try FileIndexingService.applyPreviewNames(to: items, start: -1, end: 3)) { error in
            XCTAssertEqual(error as? FileIndexingError, .invalidRange)
        }
        XCTAssertThrowsError(try FileIndexingService.applyPreviewNames(to: items, start: 5, end: 4)) { error in
            XCTAssertEqual(error as? FileIndexingError, .invalidRange)
        }
        XCTAssertThrowsError(try FileIndexingService.applyPreviewNames(to: [], start: 5, end: 4)) { error in
            XCTAssertEqual(error as? FileIndexingError, .invalidRange)
        }
    }

    func testRenameFilesEdgeCasesInvalidRangesAndRollback() throws {
        let dir = try makeTempDirectory()
        let fm = FileManager.default

        let f1 = "Screenshot 2026-11-14 at 11.00.01.png"
        let f2 = "Screenshot 2026-11-14 at 11.00.02.png"
        let f3 = "Screenshot 2026-11-14 at 11.00.03.png"
        fm.createFile(atPath: dir.appendingPathComponent(f1).path, contents: Data("one".utf8))
        fm.createFile(atPath: dir.appendingPathComponent(f2).path, contents: Data("two".utf8))
        fm.createFile(atPath: dir.appendingPathComponent(f3).path, contents: Data("three".utf8))

        let scanned = try FileIndexingService.scanFolder(at: dir.path)
        XCTAssertEqual(scanned.count, 3)

        // Empty items list
        XCTAssertThrowsError(try FileIndexingService.renameFiles(in: dir.path, items: [], start: 1, end: 3)) { error in
            XCTAssertEqual(error as? FileIndexingError, .noFiles)
        }

        // Non-existent folder and non-directory path
        XCTAssertThrowsError(
            try FileIndexingService.renameFiles(
                in: dir.appendingPathComponent("missing").path,
                items: scanned,
                start: 1,
                end: 3
            )
        ) { error in
            XCTAssertEqual(error as? FileIndexingError, .folderNotExist)
        }
        XCTAssertThrowsError(
            try FileIndexingService.renameFiles(
                in: dir.appendingPathComponent(f1).path,
                items: scanned,
                start: 1,
                end: 3
            )
        ) { error in
            XCTAssertEqual(error as? FileIndexingError, .folderNotExist)
        }

        // Invalid ranges leave original files untouched
        XCTAssertThrowsError(try FileIndexingService.renameFiles(in: dir.path, items: scanned, start: -1, end: 2)) { error in
            XCTAssertEqual(error as? FileIndexingError, .invalidRange)
        }
        XCTAssertThrowsError(try FileIndexingService.renameFiles(in: dir.path, items: scanned, start: 4, end: 2)) { error in
            XCTAssertEqual(error as? FileIndexingError, .invalidRange)
        }
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent(f1).path))
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent(f2).path))
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent(f3).path))

        // Partial range renames only the covered prefix
        let partialResult = try FileIndexingService.renameFiles(in: dir.path, items: scanned, start: 1, end: 2)
        XCTAssertEqual(partialResult.successCount, 2)
        XCTAssertEqual(partialResult.totalCount, 2)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("1.png")), Data("one".utf8))
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("2.png")), Data("two".utf8))
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(f3)), Data("three".utf8))
    }

    func testRenameFilesRollsBackRemainingTempFilesWhenStep2Fails() throws {
        let dir = try makeTempDirectory()
        let fm = FileManager.default

        let f1 = "Screenshot 2026-11-14 at 12.00.01.png"
        let f2 = "Screenshot 2026-11-14 at 12.00.02.png"
        let f3 = "Screenshot 2026-11-14 at 12.00.03.png"
        fm.createFile(atPath: dir.appendingPathComponent(f1).path, contents: Data("first".utf8))
        fm.createFile(atPath: dir.appendingPathComponent(f2).path, contents: Data("second".utf8))
        fm.createFile(atPath: dir.appendingPathComponent(f3).path, contents: Data("third".utf8))

        let scanned = try FileIndexingService.scanFolder(at: dir.path)
        XCTAssertEqual(scanned.count, 3)

        // A dangling symlink causes fileExists(atPath:) to return false while moveItem fails with EEXIST in Step 2.
        let brokenSymlinkURL = dir.appendingPathComponent("2.png")
        try fm.createSymbolicLink(at: brokenSymlinkURL, withDestinationURL: dir.appendingPathComponent("nonexistent_target.png"))

        XCTAssertThrowsError(try FileIndexingService.renameFiles(in: dir.path, items: scanned, start: 1, end: 3)) { error in
            guard case .renameFailed = error as? FileIndexingError else {
                XCTFail("Expected FileIndexingError.renameFailed, got \(error)")
                return
            }
        }

        // First file moved before failure; remaining un-moved temp files (f2, f3) must be rolled back without orphans.
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("1.png")), Data("first".utf8))
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(f2)), Data("second".utf8))
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(f3)), Data("third".utf8))

        let remainingFiles = try fm.contentsOfDirectory(atPath: dir.path)
        XCTAssertFalse(remainingFiles.contains { $0.hasPrefix("__temp_rename_") })
    }

    // MARK: - AppViewModel (@MainActor)

    @MainActor
    private func makeIsolatedViewModel() throws -> (viewModel: AppViewModel, folderURL: URL, restoreEnv: () -> Void) {
        let rootDir = try makeTempDirectory()
        let configURL = rootDir.appendingPathComponent("config/config.json")
        let folderURL = rootDir.appendingPathComponent("screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let previousEnv = ProcessInfo.processInfo.environment["SCREENSHOT_INDEXING_CONFIG_PATH"]
        setenv("SCREENSHOT_INDEXING_CONFIG_PATH", configURL.path, 1)

        let vm = AppViewModel()
        let restoreEnv: () -> Void = {
            if let previousEnv {
                setenv("SCREENSHOT_INDEXING_CONFIG_PATH", previousEnv, 1)
            } else {
                unsetenv("SCREENSHOT_INDEXING_CONFIG_PATH")
            }
        }
        return (vm, folderURL, restoreEnv)
    }

    private func createSampleScreenshots(in folderURL: URL, count: Int) -> [String] {
        let fm = FileManager.default
        var names: [String] = []
        for idx in 1 ... count {
            let sec = String(format: "%02d", idx)
            let name = "Screenshot 2026-11-14 at 10.00.\(sec).png"
            fm.createFile(atPath: folderURL.appendingPathComponent(name).path, contents: Data("img-\(idx)".utf8))
            names.append(name)
        }
        return names
    }

    @MainActor
    func testAppViewModelSyncLivePreviewRange() throws {
        let (vm, folderURL, restoreEnv) = try makeIsolatedViewModel()
        defer {
            vm.clearIndexingFolder()
            vm.dismissToast()
            restoreEnv()
        }

        _ = createSampleScreenshots(in: folderURL, count: 3)
        vm.indexingFolder = folderURL.path
        vm.scanFolder(showToastOnSuccess: false)

        XCTAssertEqual(vm.files.count, 3)
        XCTAssertEqual(vm.rangeStartText, "1")
        XCTAssertEqual(vm.rangeEndText, "3")
        XCTAssertEqual(vm.files.map(\.previewNewName), ["1.png", "2.png", "3.png"])

        // Partial range updates matching subset and clears trailing items
        vm.rangeStartText = "10"
        vm.rangeEndText = "11"
        vm.syncLivePreviewRange()
        XCTAssertEqual(vm.files.map(\.previewNewName), ["10.png", "11.png", nil])

        // Zero-based start is valid
        vm.rangeStartText = "0"
        vm.rangeEndText = "1"
        vm.syncLivePreviewRange()
        XCTAssertEqual(vm.files.map(\.previewNewName), ["0.png", "1.png", nil])

        // start > end clears all previewNewName values
        vm.rangeStartText = "5"
        vm.rangeEndText = "2"
        vm.syncLivePreviewRange()
        XCTAssertEqual(vm.files.map(\.previewNewName), [nil, nil, nil])

        // Restore valid range, then verify negative/non-numeric/empty bounds clear previews
        vm.rangeStartText = "1"
        vm.rangeEndText = "3"
        vm.syncLivePreviewRange()
        XCTAssertEqual(vm.files.map(\.previewNewName), ["1.png", "2.png", "3.png"])

        vm.rangeStartText = "-1"
        vm.rangeEndText = "2"
        vm.syncLivePreviewRange()
        XCTAssertEqual(vm.files.map(\.previewNewName), [nil, nil, nil])

        vm.rangeStartText = "abc"
        vm.rangeEndText = "3"
        vm.syncLivePreviewRange()
        XCTAssertEqual(vm.files.map(\.previewNewName), [nil, nil, nil])

        vm.rangeStartText = "1"
        vm.rangeEndText = ""
        vm.syncLivePreviewRange()
        XCTAssertEqual(vm.files.map(\.previewNewName), [nil, nil, nil])
    }

    @MainActor
    func testAppViewModelRequestRename() throws {
        let (vm, folderURL, restoreEnv) = try makeIsolatedViewModel()
        defer {
            vm.clearIndexingFolder()
            vm.dismissToast()
            restoreEnv()
        }

        // Empty files must not present confirm rename sheet
        vm.requestRename()
        XCTAssertFalse(vm.showConfirmRenameSheet)
        XCTAssertNil(vm.pendingRenameRange)

        let names = createSampleScreenshots(in: folderURL, count: 3)
        vm.indexingFolder = folderURL.path
        vm.scanFolder(showToastOnSuccess: false)

        // Invalid range must not present confirm rename sheet
        vm.rangeStartText = "5"
        vm.rangeEndText = "2"
        vm.requestRename()
        XCTAssertFalse(vm.showConfirmRenameSheet)
        XCTAssertNil(vm.pendingRenameRange)

        // Valid partial range sets pending rename bounds and preview strings
        vm.rangeStartText = "10"
        vm.rangeEndText = "11"
        vm.requestRename()
        XCTAssertTrue(vm.showConfirmRenameSheet)
        XCTAssertEqual(vm.pendingRenameRange?.start, 10)
        XCTAssertEqual(vm.pendingRenameRange?.end, 11)
        XCTAssertEqual(vm.pendingRenameRange?.count, 2)
        XCTAssertEqual(vm.pendingFirstOld, names[0])
        XCTAssertEqual(vm.pendingFirstNew, "10.png")
        XCTAssertEqual(vm.pendingLastOld, names[1])
        XCTAssertEqual(vm.pendingLastNew, "11.png")

        vm.cancelRename()
        XCTAssertFalse(vm.showConfirmRenameSheet)
        XCTAssertNil(vm.pendingRenameRange)
    }

    @MainActor
    func testAppViewModelClearIndexingFolder() throws {
        let (vm, folderURL, restoreEnv) = try makeIsolatedViewModel()
        defer {
            vm.clearIndexingFolder()
            vm.dismissToast()
            restoreEnv()
        }

        _ = createSampleScreenshots(in: folderURL, count: 2)
        vm.indexingFolder = folderURL.path
        vm.scanFolder(showToastOnSuccess: false)
        vm.indexingStatusIsError = true
        vm.indexingStatusText = "Some error"
        vm.openPreview(at: 1)
        vm.showSingleImageSummaryPopover = true
        vm.requestRename()

        XCTAssertFalse(vm.files.isEmpty)
        XCTAssertTrue(vm.showConfirmRenameSheet)
        XCTAssertEqual(vm.previewImageIndex, 1)

        vm.clearIndexingFolder()

        XCTAssertEqual(vm.indexingFolder, "")
        XCTAssertTrue(vm.files.isEmpty)
        XCTAssertEqual(vm.rangeStartText, "")
        XCTAssertEqual(vm.rangeEndText, "")
        XCTAssertEqual(vm.indexingStatusText, "")
        XCTAssertFalse(vm.indexingStatusIsError)
        XCTAssertFalse(vm.showConfirmRenameSheet)
        XCTAssertNil(vm.pendingRenameRange)
        XCTAssertNil(vm.previewImageIndex)
        XCTAssertFalse(vm.showSingleImageSummaryPopover)
    }

    @MainActor
    func testAppViewModelSelectTabAndScanFolderStateCleanup() throws {
        let (vm, folderURL, restoreEnv) = try makeIsolatedViewModel()
        defer {
            vm.clearIndexingFolder()
            vm.dismissToast()
            restoreEnv()
        }

        let names = createSampleScreenshots(in: folderURL, count: 2)
        vm.indexingFolder = folderURL.path
        vm.scanFolder(showToastOnSuccess: false)

        vm.openPreview(at: 1)
        vm.showSingleImageSummaryPopover = true
        vm.requestRename()

        // Re-selecting the current tab keeps rename and preview state intact
        vm.selectTab(.indexing)
        XCTAssertEqual(vm.activeTab, .indexing)
        XCTAssertTrue(vm.showConfirmRenameSheet)
        XCTAssertNotNil(vm.pendingRenameRange)
        XCTAssertEqual(vm.previewImageIndex, 1)
        XCTAssertTrue(vm.showSingleImageSummaryPopover)

        // Switching to a different tab cancels rename and closes preview + summary popover
        vm.selectTab(.settings)
        XCTAssertEqual(vm.activeTab, .settings)
        XCTAssertFalse(vm.showConfirmRenameSheet)
        XCTAssertNil(vm.pendingRenameRange)
        XCTAssertNil(vm.previewImageIndex)
        XCTAssertFalse(vm.showSingleImageSummaryPopover)

        // When autoCaptureEnabled is false, selecting .capture resolves to .indexing and cleans up state
        vm.updateConfig { $0.autoCaptureEnabled = false }
        vm.openPreview(at: 0)
        vm.requestRename()
        vm.selectTab(.capture)
        XCTAssertEqual(vm.activeTab, .indexing)
        XCTAssertFalse(vm.showConfirmRenameSheet)
        XCTAssertNil(vm.pendingRenameRange)
        XCTAssertNil(vm.previewImageIndex)

        // Rescanning after removing a file cancels rename and closes out-of-bounds preview
        vm.openPreview(at: 1)
        vm.requestRename()
        try FileManager.default.removeItem(at: folderURL.appendingPathComponent(names[1]))
        vm.scanFolder(showToastOnSuccess: false)
        XCTAssertEqual(vm.files.count, 1)
        XCTAssertFalse(vm.showConfirmRenameSheet)
        XCTAssertNil(vm.pendingRenameRange)
        XCTAssertNil(vm.previewImageIndex)
    }
}
