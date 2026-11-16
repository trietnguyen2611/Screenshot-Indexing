import CoreGraphics
import Foundation
import FoundationModels
import ImageIO
import Vision

/// Availability state of the on-device Apple Foundation Model engine.
enum AFMAvailabilityStatus: Equatable, Sendable {
    case available
    case unavailable(reason: String)

    var isAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }

    var reasonCode: String {
        switch self {
        case .available:
            return "available"
        case .unavailable(let reason):
            return reason
        }
    }
}

/// Errors emitted during on-device Vision OCR and Apple Foundation Models summarization.
enum AFMSummarizerError: LocalizedError, Equatable, Sendable {
    case unavailable(String)
    case noValidImages
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            return "Apple Foundation Model unavailable: \(reason)"
        case .noValidImages:
            return "No valid image files found"
        case .generationFailed(let message):
            return message
        }
    }
}

/// In-process on-device OCR (Vision) and summarization (Apple Foundation Models) service.
final class AFMSummarizerService: Sendable {
    static let shared = AFMSummarizerService()

    private init() {}

    /// Query the current availability of the default on-device `SystemLanguageModel`.
    func checkAvailability() -> AFMAvailabilityStatus {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable(reason: "device_not_eligible")
            case .appleIntelligenceNotEnabled:
                return .unavailable(reason: "apple_intelligence_not_enabled")
            case .modelNotReady:
                return .unavailable(reason: "model_not_ready")
            @unknown default:
                return .unavailable(reason: "unavailable")
            }
        }
    }

    /// Run concurrent Vision OCR across up to 8 images and stream an on-device AFM summary.
    func streamSummary(
        imageURLs: [URL],
        lang: AppLanguage,
        onUpdate: @MainActor @Sendable (String) -> Void
    ) async throws -> (summary: String, processedCount: Int) {
        let status = checkAvailability()
        guard status.isAvailable else {
            throw AFMSummarizerError.unavailable(status.reasonCode)
        }

        let validURLs = Array(
            imageURLs
                .filter { FileManager.default.fileExists(atPath: $0.path) }
                .prefix(8)
        )
        guard !validURLs.isEmpty else {
            throw AFMSummarizerError.noValidImages
        }

        let extracted = await extractAllConcurrently(urls: validURLs, lang: lang)
        let processedCount = extracted.count
        guard processedCount > 0 else {
            throw AFMSummarizerError.noValidImages
        }

        try Task.checkCancellation()

        let combinedOCR = extracted.map { item in
            let body = item.text.isEmpty ? "(no readable text)" : item.text
            return "[\(item.index + 1)] \(item.name):\n\(body)"
        }.joined(separator: "\n\n")

        let instructions: String
        let prompt: String
        switch lang {
        case .vi:
            instructions = "Bạn là trợ lý kỹ thuật. Tóm tắt cực kỳ ngắn gọn bằng tiếng Việt dưới dạng Markdown."
            prompt = "Tóm tắt các điểm chính từ nội dung OCR sau:\n\n\(combinedOCR)"
        case .en:
            instructions = "You are a technical assistant. Write ultra-concise Markdown bullet notes in English."
            prompt = "Summarize key points from this OCR text:\n\n\(combinedOCR)"
        }

        do {
            let session = LanguageModelSession(instructions: instructions)
            var lastContent = ""
            let stream = session.streamResponse(to: prompt)
            for try await partial in stream {
                try Task.checkCancellation()
                let current = partial.content
                if current != lastContent {
                    lastContent = current
                    await onUpdate(current)
                }
            }

            let trimmed = lastContent.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                throw AFMSummarizerError.generationFailed("Empty summary returned by Apple Foundation Model.")
            }
            return (summary: trimmed, processedCount: processedCount)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AFMSummarizerError {
            throw error
        } catch {
            throw AFMSummarizerError.generationFailed(error.localizedDescription)
        }
    }

    // MARK: - Vision OCR Helpers

    private func loadThumbnailCGImage(at url: URL, maxPixelSize: Int = 1600) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private func extractText(from url: URL, lang: AppLanguage) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        switch lang {
        case .vi:
            request.recognitionLanguages = ["vi-VN", "en-US"]
        case .en:
            request.recognitionLanguages = ["en-US", "vi-VN"]
        }

        let handler: VNImageRequestHandler
        if let thumbnail = loadThumbnailCGImage(at: url, maxPixelSize: 1600) {
            handler = VNImageRequestHandler(cgImage: thumbnail, options: [:])
        } else {
            handler = VNImageRequestHandler(url: url, options: [:])
        }

        do {
            try handler.perform([request])
        } catch {
            return ""
        }

        let observations = request.results ?? []
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        return lines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractAllConcurrently(
        urls: [URL],
        lang: AppLanguage
    ) async -> [(index: Int, name: String, text: String)] {
        guard !urls.isEmpty else { return [] }
        let perImageLimit = max(450, 5000 / urls.count)

        return await withTaskGroup(of: (Int, String, String).self) { group in
            for (idx, url) in urls.enumerated() {
                group.addTask { [self] in
                    let raw = self.extractText(from: url, lang: lang)
                    let clipped = String(raw.prefix(perImageLimit))
                    return (idx, url.lastPathComponent, clipped)
                }
            }

            var results: [(Int, String, String)] = []
            results.reserveCapacity(urls.count)
            for await item in group {
                results.append(item)
            }
            return results.sorted { $0.0 < $1.0 }
        }
    }
}
