import Foundation
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

func emitJSON(_ payload: ResponsePayload) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.withoutEscapingSlashes]
    if let data = try? encoder.encode(payload),
       let text = String(data: data, encoding: .utf8) {
        print(text)
    } else {
        print("{\"ok\":false,\"error\":\"Failed to encode JSON response\"}")
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

func extractText(from imagePath: String, lang: String) -> String {
    let url = URL(fileURLWithPath: imagePath)
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = lang == "vi" ? ["vi-VN", "en-US"] : ["en-US", "vi-VN"]

    let handler = VNImageRequestHandler(url: url, options: [:])
    do {
        try handler.perform([request])
    } catch {
        return ""
    }

    let observations = request.results ?? []
    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
    return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
}

@main
struct AFMHelperCLI {
    static func main() async {
        let args = CommandLine.arguments
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
            emitJSON(ResponsePayload(
                ok: false,
                available: nil,
                reason: nil,
                summary: nil,
                processed: nil,
                error: "Invalid JSON input"
            ))
            return
        }

        let status = availabilityStatus()
        guard status.available else {
            emitJSON(ResponsePayload(
                ok: false,
                available: false,
                reason: status.reason,
                summary: nil,
                processed: 0,
                error: "Apple Foundation Model unavailable: \(status.reason)"
            ))
            return
        }

        var extractedSections: [String] = []
        var processedCount = 0

        for (idx, path) in req.images.prefix(12).enumerated() {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            processedCount += 1
            let text = extractText(from: path, lang: req.lang)
            let name = URL(fileURLWithPath: path).lastPathComponent
            if !text.isEmpty {
                let clipped = String(text.prefix(1800))
                extractedSections.append("[\(idx + 1)] \(name):\n\(clipped)")
            } else {
                extractedSections.append("[\(idx + 1)] \(name): (no readable text)")
            }
        }

        guard processedCount > 0 else {
            emitJSON(ResponsePayload(
                ok: false,
                available: true,
                reason: "available",
                summary: nil,
                processed: 0,
                error: "No valid image files found"
            ))
            return
        }

        let combinedOCR = extractedSections.joined(separator: "\n\n")
        let instructions: String
        let prompt: String
        if req.lang == "vi" {
            instructions = "Bạn là trợ lý kỹ thuật tóm tắt ghi chú ngắn gọn, chính xác bằng tiếng Việt dưới dạng Markdown."
            prompt = """
            Dưới đây là nội dung OCR trích xuất từ các ảnh chụp màn hình theo thứ tự. Hãy tóm tắt thành ghi chú Markdown rõ ràng (tiêu đề ngắn theo từng ảnh/chủ đề và các gạch đầu dòng ý chính):

            \(combinedOCR)
            """
        } else {
            instructions = "You are a technical assistant that writes concise, structured Markdown study and reference notes in English."
            prompt = """
            Below is OCR text extracted chronologically from screenshots. Summarize the key points into clean Markdown notes (short heading per screenshot/topic and concise bullet points):

            \(combinedOCR)
            """
        }

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            let summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            emitJSON(ResponsePayload(
                ok: true,
                available: true,
                reason: "available",
                summary: summary,
                processed: processedCount,
                error: nil
            ))
        } catch {
            emitJSON(ResponsePayload(
                ok: false,
                available: true,
                reason: "available",
                summary: nil,
                processed: processedCount,
                error: error.localizedDescription
            ))
        }
    }
}
