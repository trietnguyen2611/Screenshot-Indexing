import Foundation

public enum FileIndexingError: LocalizedError, Equatable, Sendable {
    case folderNotExist
    case noFiles
    case invalidRange
    case renameFailed(String)

    public var errorDescription: String? {
        switch self {
        case .folderNotExist:
            return "Folder does not exist"
        case .noFiles:
            return "No files to rename"
        case .invalidRange:
            return "Invalid start/end range"
        case .renameFailed(let message):
            return message
        }
    }
}

public enum FileIndexingService {
    private static let timestampRegex: NSRegularExpression = {
        // Matches HH.MM.SS before the file extension (e.g., "Screenshot 2026-01-01 at 10.02.05.png")
        try! NSRegularExpression(pattern: #"(\d+)\.(\d+)\.(\d+)\.\w+$"#, options: [])
    }()

    private static let screenshotPrefixes = [
        "screenshot",
        "ảnh màn hình",
        "anh man hinh",
    ]

    public static func isScreenshotFile(_ filename: String) -> Bool {
        guard filename.lowercased().hasSuffix(".png") else {
            return false
        }
        let normNFC = filename.precomposedStringWithCanonicalMapping.lowercased()
        let normNFD = filename.decomposedStringWithCanonicalMapping.lowercased()

        for prefix in screenshotPrefixes {
            let prefNFC = prefix.precomposedStringWithCanonicalMapping.lowercased()
            let prefNFD = prefix.decomposedStringWithCanonicalMapping.lowercased()
            if normNFC.hasPrefix(prefNFC) || normNFD.hasPrefix(prefNFD) {
                return true
            }
        }
        return false
    }

    public static func sortKey(for filename: String) -> Int {
        guard let groups = matchTimestampGroups(in: filename) else {
            return 0
        }
        return groups.hours * 3600 + groups.minutes * 60 + groups.seconds
    }

    public static func secondsDisplay(for filename: String) -> String {
        guard let groups = matchTimestampGroups(in: filename) else {
            return "?"
        }
        return groups.secondsText
    }

    public static func scanFolder(at folderPath: String) throws -> [ScreenshotItem] {
        let expandedPath = normalizeFolderPath(folderPath)
        var isDirectory: ObjCBool = false
        guard !expandedPath.isEmpty,
              FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FileIndexingError.folderNotExist
        }

        let folderURL = URL(fileURLWithPath: expandedPath, isDirectory: true)
        let entries: [String]
        do {
            entries = try FileManager.default.contentsOfDirectory(atPath: expandedPath)
        } catch {
            throw FileIndexingError.folderNotExist
        }

        let filtered = entries.filter { name in
            guard isScreenshotFile(name) else { return false }
            let itemPath = folderURL.appendingPathComponent(name).path
            var itemIsDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: itemPath, isDirectory: &itemIsDir) && !itemIsDir.boolValue
        }

        let sorted = filtered.sorted { lhs, rhs in
            let lKey = sortKey(for: lhs)
            let rKey = sortKey(for: rhs)
            if lKey != rKey {
                return lKey < rKey
            }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }

        return sorted.enumerated().map { idx, filename in
            ScreenshotItem(
                index: idx + 1,
                name: filename,
                url: folderURL.appendingPathComponent(filename),
                secondsDisplay: secondsDisplay(for: filename),
                sortKey: sortKey(for: filename),
                previewNewName: nil
            )
        }
    }

    public static func applyPreviewNames(
        to items: [ScreenshotItem],
        start: Int,
        end: Int
    ) throws -> [ScreenshotItem] {
        guard start >= 0, end >= start else {
            throw FileIndexingError.invalidRange
        }

        let totalNumbers = end - start + 1
        let count = min(items.count, totalNumbers)

        return items.enumerated().map { idx, item in
            var copy = item
            copy.previewNewName = idx < count ? "\(start + idx).png" : nil
            return copy
        }
    }

    public static func renameFiles(
        in folderPath: String,
        items: [ScreenshotItem],
        start: Int,
        end: Int
    ) throws -> (successCount: Int, totalCount: Int) {
        guard !items.isEmpty else {
            throw FileIndexingError.noFiles
        }

        let expandedPath = normalizeFolderPath(folderPath)
        var isDirectory: ObjCBool = false
        guard !expandedPath.isEmpty,
              FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FileIndexingError.folderNotExist
        }

        guard start >= 0, end >= start else {
            throw FileIndexingError.invalidRange
        }

        let fm = FileManager.default
        let folderURL = URL(fileURLWithPath: expandedPath, isDirectory: true)
        let totalNumbers = end - start + 1
        let count = min(items.count, totalNumbers)

        var renamePairs: [(oldName: String, newName: String)] = []
        renamePairs.reserveCapacity(count)
        for i in 0 ..< count {
            let oldName = items[i].name
            let newName = "\(start + i).png"
            renamePairs.append((oldName: oldName, newName: newName))
        }

        // Step 1: Move all targets to collision-free temporary names.
        let batchToken = UUID().uuidString.lowercased()
        var tempPairs: [(oldName: String, tempName: String, newName: String)] = []
        tempPairs.reserveCapacity(count)
        do {
            for pair in renamePairs {
                let tempName = "__temp_rename_\(batchToken)_\(pair.newName)"
                let oldURL = folderURL.appendingPathComponent(pair.oldName)
                let tempURL = folderURL.appendingPathComponent(tempName)
                try fm.moveItem(at: oldURL, to: tempURL)
                tempPairs.append((oldName: pair.oldName, tempName: tempName, newName: pair.newName))
            }
        } catch {
            // Best-effort rollback of any files already moved to temp names in Step 1.
            for moved in tempPairs.reversed() {
                let tempURL = folderURL.appendingPathComponent(moved.tempName)
                let oldURL = folderURL.appendingPathComponent(moved.oldName)
                if fm.fileExists(atPath: tempURL.path), !fm.fileExists(atPath: oldURL.path) {
                    try? fm.moveItem(at: tempURL, to: oldURL)
                }
            }
            throw FileIndexingError.renameFailed(error.localizedDescription)
        }

        // Step 2: Move from temporary names to final numbered names without overwriting existing files.
        var successCount = 0
        for item in tempPairs {
            let tempURL = folderURL.appendingPathComponent(item.tempName)
            let newURL = folderURL.appendingPathComponent(item.newName)
            if fm.fileExists(atPath: newURL.path) {
                // Restore original filename rather than leaving an orphaned __temp_rename_ file behind.
                let oldURL = folderURL.appendingPathComponent(item.oldName)
                if !fm.fileExists(atPath: oldURL.path) {
                    try? fm.moveItem(at: tempURL, to: oldURL)
                }
                continue
            }
            do {
                try fm.moveItem(at: tempURL, to: newURL)
                successCount += 1
            } catch {
                // Best-effort rollback of any remaining temp files so they are not left orphaned.
                for candidate in tempPairs.reversed() {
                    let candidateTempURL = folderURL.appendingPathComponent(candidate.tempName)
                    let candidateOldURL = folderURL.appendingPathComponent(candidate.oldName)
                    if fm.fileExists(atPath: candidateTempURL.path), !fm.fileExists(atPath: candidateOldURL.path) {
                        try? fm.moveItem(at: candidateTempURL, to: candidateOldURL)
                    }
                }
                throw FileIndexingError.renameFailed(error.localizedDescription)
            }
        }

        return (successCount: successCount, totalCount: count)
    }

    private static func normalizeFolderPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return (trimmed as NSString).expandingTildeInPath
    }

    private static func matchTimestampGroups(in filename: String) -> (hours: Int, minutes: Int, seconds: Int, secondsText: String)? {
        let nsRange = NSRange(filename.startIndex ..< filename.endIndex, in: filename)
        guard let match = timestampRegex.firstMatch(in: filename, options: [], range: nsRange),
              match.numberOfRanges >= 4,
              let hRange = Range(match.range(at: 1), in: filename),
              let mRange = Range(match.range(at: 2), in: filename),
              let sRange = Range(match.range(at: 3), in: filename),
              let hours = Int(filename[hRange]),
              let minutes = Int(filename[mRange]),
              let seconds = Int(filename[sRange]) else {
            return nil
        }
        return (hours: hours, minutes: minutes, seconds: seconds, secondsText: String(filename[sRange]))
    }
}
