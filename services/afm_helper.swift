import Foundation
import CoreGraphics
import ImageIO
import Vision
import FoundationModels

struct RequestPayload: Decodable {
    let images: [String]
    let lang: String
}

struct ResponsePayload: Encodable {
    let ok: Bool
    let available: Bool?
    let reason: String?
    let summary: String?
    let processed: Int?
    let error: String?
}

struct StreamEvent: Encodable {
    let type: String
    let text: String?
    let processed: Int?
    let reason: String?
    let error: String?
}

func emitJSON<T: Encodable>(_ payload: T) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.withoutEscapingSlashes]
    if let data = try? encoder.encode(payload),
       let text = String(data: data, encoding: .utf8) {
        print(text)
        fflush(stdout)
    }
}

func availabilityStatus() -> (available: Bool, reason: String) {
    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
        return (true, "available")
    case .unavailable(let reason):
        switch reason {
        case .deviceNotEligible:
            return (false, "device_not_eligible")
        case .appleIntelligenceNotEnabled:
            return (false, "apple_intelligence_not_enabled")
        case .modelNotReady:
            return (false, "model_not_ready")
        @unknown default:
            return (false, "unavailable")
        }
    }
}

func loadThumbnailCGImage(at url: URL, maxPixelSize: Int = 1600) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        return nil
    }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        kCGImageSourceCreateThumbnailWithTransform: true,
    ]
    return CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary)
}

func extractText(from imagePath: String, lang: String) -> String {
    let url = URL(fileURLWithPath: imagePath)
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.recognitionLanguages = lang == "vi" ? ["vi-VN", "en-US"] : ["en-US", "vi-VN"]

    let handler: VNImageRequestHandler
    if let cgImg = loadThumbnailCGImage(at: url, maxPixelSize: 1600) {
        handler = VNImageRequestHandler(cgImage: cgImg, options: [:])
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
    return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
}

func extractAllConcurrently(paths: [String], lang: String) async -> [(index: Int, name: String, text: String)] {
    let validPaths = paths.prefix(8).filter { FileManager.default.fileExists(atPath: $0) }
    guard !validPaths.isEmpty else { return [] }

    let perImageLimit = max(450, 5000 / validPaths.count)
    return await withTaskGroup(of: (Int, String, String).self) { group in
        for (idx, path) in validPaths.enumerated() {
            group.addTask {
                let raw = extractText(from: path, lang: lang)
                let clipped = String(raw.prefix(perImageLimit))
                let name = URL(fileURLWithPath: path).lastPathComponent
                return (idx, name, clipped)
            }
        }
        var results: [(Int, String, String)] = []
        for await item in group {
            results.append(item)
        }
        return results.sorted { $0.0 < $1.0 }
    }
}

@main
struct AFMHelperCLI {
    static func main() async {
        let args = CommandLine.arguments
        let streamMode = args.contains("--stream")

        if args.contains("--check") {
            let status = availabilityStatus()
            emitJSON(ResponsePayload(
                ok: true,
                available: status.available,
                reason: status.reason,
                summary: nil,
                processed: nil,
                error: nil
            ))
            return
        }

        let inputData = FileHandle.standardInput.readDataToEndOfFile()
        guard !inputData.isEmpty,
              let req = try? JSONDecoder().decode(RequestPayload.self, from: inputData) else {
            if streamMode {
                emitJSON(StreamEvent(type: "error", text: nil, processed: nil, reason: "invalid_input", error: "Invalid JSON input"))
            } else {
                emitJSON(ResponsePayload(ok: false, available: nil, reason: nil, summary: nil, processed: nil, error: "Invalid JSON input"))
            }
            return
        }

        let status = availabilityStatus()
        guard status.available else {
            if streamMode {
                emitJSON(StreamEvent(type: "error", text: nil, processed: 0, reason: status.reason, error: "Apple Foundation Model unavailable: \(status.reason)"))
            } else {
                emitJSON(ResponsePayload(ok: false, available: false, reason: status.reason, summary: nil, processed: 0, error: "Apple Foundation Model unavailable: \(status.reason)"))
            }
            return
        }

        let extracted = await extractAllConcurrently(paths: req.images, lang: req.lang)
        let processedCount = extracted.count

        guard processedCount > 0 else {
            if streamMode {
                emitJSON(StreamEvent(type: "error", text: nil, processed: 0, reason: "no_images", error: "No valid image files found"))
            } else {
                emitJSON(ResponsePayload(ok: false, available: true, reason: "available", summary: nil, processed: 0, error: "No valid image files found"))
            }
            return
        }

        let combinedOCR = extracted.map { item in
            let body = item.text.isEmpty ? "(no readable text)" : item.text
            return "[\(item.index + 1)] \(item.name):\n\(body)"
        }.joined(separator: "\n\n")

        let instructions: String
        let prompt: String
        if req.lang == "vi" {
            instructions = "Bạn là trợ lý kỹ thuật. Tóm tắt cực kỳ ngắn gọn bằng tiếng Việt dưới dạng Markdown."
            prompt = "Tóm tắt các điểm chính từ nội dung OCR sau:\n\n\(combinedOCR)"
        } else {
            instructions = "You are a technical assistant. Write ultra-concise Markdown bullet notes in English."
            prompt = "Summarize key points from this OCR text:\n\n\(combinedOCR)"
        }

        do {
            let session = LanguageModelSession(instructions: instructions)
            if streamMode {
                var lastContent = ""
                let stream = session.streamResponse(to: prompt)
                for try await partial in stream {
                    let current = partial.content
                    if current.count > lastContent.count, current.hasPrefix(lastContent) {
                        let delta = String(current.dropFirst(lastContent.count))
                        if !delta.isEmpty {
                            emitJSON(StreamEvent(type: "delta", text: delta, processed: nil, reason: nil, error: nil))
                        }
                        lastContent = current
                    } else if current != lastContent {
                        // Fallback if prefix changed
                        emitJSON(StreamEvent(type: "replace", text: current, processed: nil, reason: nil, error: nil))
                        lastContent = current
                    }
                }
                emitJSON(StreamEvent(type: "done", text: nil, processed: processedCount, reason: nil, error: nil))
            } else {
                let response = try await session.respond(to: prompt)
                let summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                emitJSON(ResponsePayload(ok: true, available: true, reason: "available", summary: summary, processed: processedCount, error: nil))
            }
        } catch {
            if streamMode {
                emitJSON(StreamEvent(type: "error", text: nil, processed: processedCount, reason: "afm_error", error: error.localizedDescription))
            } else {
                emitJSON(ResponsePayload(ok: false, available: true, reason: "available", summary: nil, processed: processedCount, error: error.localizedDescription))
            }
        }
    }
}
