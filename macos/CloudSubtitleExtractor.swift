import AppKit
import AVFoundation
import Foundation
import Security

enum CloudSubtitleCredentialStore {
    private static let service = "com.cinemaparadiso.directorworkbench.cloud-subtitle.openai"
    private static let account = "api-key"

    static var isConfigured: Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    static func loadKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard
            status == errSecSuccess,
            let data = result as? Data,
            let key = String(data: data, encoding: .utf8),
            !key.isEmpty
        else {
            throw CredentialError.notConfigured
        }
        return key
    }

    static func save(key: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw CredentialError.invalid
        }
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw CredentialError.saveFailed
        }

        var item = identity
        attributes.forEach { item[$0.key] = $0.value }
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
            throw CredentialError.saveFailed
        }
    }

    static func remove() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialError.removeFailed
        }
    }

    enum CredentialError: Error {
        case invalid
        case notConfigured
        case saveFailed
        case removeFailed
    }
}

struct CloudSubtitleCue {
    let start: Double
    let end: Double
    let text: String
    let confidence: Double

    var bridgeValue: [String: Any] {
        [
            "start": start,
            "end": end,
            "text": text,
            "confidence": confidence,
            "source": "cloud-ocr",
        ]
    }
}

struct CloudSubtitleOutcome {
    let provider: String
    let model: String
    let cues: [CloudSubtitleCue]
    let sampledFrameCount: Int
    let uploadedFrameCount: Int
    let errorMessage: String?

    var bridgeValue: [String: Any] {
        let joinedText = cues.map(\.text).joined(separator: "\n")
        let isChinese = CloudSubtitleExtractor.containsChinese(joinedText)
        var value: [String: Any] = [
            "provider": provider,
            "model": model,
            "found": !cues.isEmpty,
            "sourceType": "cloud-ocr",
            "sourceName": "OpenAI 云端画面字幕提取（经济模式）",
            "language": isChinese ? "zh" : "",
            "isChinese": isChinese,
            "candidateCount": cues.isEmpty ? 0 : 1,
            "cueCount": cues.count,
            "sampledFrameCount": sampledFrameCount,
            "uploadedFrameCount": uploadedFrameCount,
            "cues": cues.map(\.bridgeValue),
            "scannedAt": ISO8601DateFormatter().string(from: Date()),
        ]
        if let errorMessage {
            value["error"] = errorMessage
        }
        return value
    }
}

struct CloudSubtitleProgress {
    let processed: Int
    let total: Int
    let message: String

    var bridgeValue: [String: Any] {
        [
            "processed": processed,
            "total": total,
            "percent": Int((Double(processed) / Double(max(1, total))) * 100),
            "message": message,
        ]
    }
}

struct CloudSubtitleExtractor {
    typealias RequestExecutor = (URLRequest) async throws -> (Data, URLResponse)
    typealias ProgressReporter = (CloudSubtitleProgress) -> Void

    private struct FrameSample {
        let id: Int
        let time: Double
        let imageData: Data
    }

    private struct RecognizedFrameText {
        let id: Int
        let text: String
        let confidence: Double
    }

    private struct MutableCue {
        var start: Double
        var end: Double
        var text: String
        var confidenceTotal: Double
        var count: Int

        var cue: CloudSubtitleCue {
            CloudSubtitleCue(
                start: start,
                end: end,
                text: text,
                confidence: confidenceTotal / Double(max(1, count))
            )
        }
    }

    private let endpoint: URL
    private let model: String
    private let sampleInterval: Double
    private let maxFrames: Int
    private let batchSize: Int
    private let requestDelayNanoseconds: UInt64
    private let execute: RequestExecutor

    init(
        endpoint: URL = URL(string: "https://api.openai.com/v1/chat/completions")!,
        model: String = "gpt-5-mini",
        sampleInterval: Double = 2.0,
        maxFrames: Int = 4_200,
        batchSize: Int = 3,
        requestDelaySeconds: Double = 4.0,
        execute: @escaping RequestExecutor = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.endpoint = endpoint
        self.model = model
        self.sampleInterval = max(1.0, sampleInterval)
        self.maxFrames = max(1, maxFrames)
        self.batchSize = max(1, batchSize)
        self.requestDelayNanoseconds = UInt64(max(0, requestDelaySeconds) * 1_000_000_000)
        self.execute = execute
    }

    func extract(
        videoURL: URL,
        duration: Double,
        apiKey: String,
        progress: ProgressReporter? = nil
    ) async -> CloudSubtitleOutcome {
        let asset = AVURLAsset(url: videoURL)
        let assetDuration = asset.duration.seconds
        let safeDuration = duration.isFinite && duration > 0
            ? duration
            : (assetDuration.isFinite ? assetDuration : 0)
        guard safeDuration > 0 else {
            return outcome(error: "当前影片时长异常，无法云端提取字幕")
        }

        let times = sampleTimes(duration: safeDuration)
        guard !times.isEmpty else {
            return outcome(error: "当前影片没有可分析的字幕画面")
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 960, height: 540)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.12, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.12, preferredTimescale: 600)

        var recognized: [RecognizedFrameText] = []
        var uploadedFrameCount = 0
        var processedCount = 0

        for timeBatch in times.chunked(into: batchSize) {
            let samples = timeBatch.compactMap { pair -> FrameSample? in
                autoreleasepool {
                    guard
                        let image = try? generator.copyCGImage(
                            at: CMTime(seconds: pair.time, preferredTimescale: 600),
                            actualTime: nil
                        ),
                        let imageData = jpegSubtitleStrip(from: image)
                    else {
                        return nil
                    }
                    return FrameSample(
                        id: pair.id,
                        time: pair.time,
                        imageData: imageData
                    )
                }
            }
            processedCount += timeBatch.count
            guard !samples.isEmpty else {
                progress?(
                    CloudSubtitleProgress(
                        processed: processedCount,
                        total: times.count,
                        message: "正在准备字幕区域画面…"
                    )
                )
                continue
            }

            do {
                let batchResult = try await recognizeBatchWithRetry(
                    samples,
                    apiKey: apiKey,
                    processedCount: processedCount,
                    totalCount: times.count,
                    progress: progress
                )
                recognized.append(contentsOf: batchResult)
                uploadedFrameCount += samples.count
                progress?(
                    CloudSubtitleProgress(
                        processed: processedCount,
                        total: times.count,
                        message: "正在读取画面字幕…"
                    )
                )
                if requestDelayNanoseconds > 0 {
                    try? await Task.sleep(nanoseconds: requestDelayNanoseconds)
                }
            } catch {
                return CloudSubtitleOutcome(
                    provider: "openai",
                    model: model,
                    cues: mergeRecognizedFrames(
                        recognized,
                        frameTimes: Dictionary(uniqueKeysWithValues: times.map { ($0.id, $0.time) }),
                        duration: safeDuration
                    ),
                    sampledFrameCount: times.count,
                    uploadedFrameCount: uploadedFrameCount,
                    errorMessage: userMessage(for: error)
                )
            }
        }

        let cues = mergeRecognizedFrames(
            recognized,
            frameTimes: Dictionary(uniqueKeysWithValues: times.map { ($0.id, $0.time) }),
            duration: safeDuration
        )
        return CloudSubtitleOutcome(
            provider: "openai",
            model: model,
            cues: cues,
            sampledFrameCount: times.count,
            uploadedFrameCount: uploadedFrameCount,
            errorMessage: cues.isEmpty ? "云端没有从画面中读到字幕，可以换更清晰片源或稍后重试" : nil
        )
    }

    static func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains {
            (0x3400...0x4DBF).contains($0.value)
                || (0x4E00...0x9FFF).contains($0.value)
                || (0xF900...0xFAFF).contains($0.value)
        }
    }

    private func outcome(error: String) -> CloudSubtitleOutcome {
        CloudSubtitleOutcome(
            provider: "openai",
            model: model,
            cues: [],
            sampledFrameCount: 0,
            uploadedFrameCount: 0,
            errorMessage: error
        )
    }

    private func sampleTimes(duration: Double) -> [(id: Int, time: Double)] {
        let firstTime = min(1.0, max(0.2, duration * 0.05))
        let lastTime = max(firstTime, duration - 0.3)
        var values: [(id: Int, time: Double)] = []
        var time = firstTime
        var id = 0
        while time <= lastTime && values.count < maxFrames {
            values.append((id: id, time: time))
            id += 1
            time += sampleInterval
        }
        return values
    }

    private func jpegSubtitleStrip(from image: CGImage) -> Data? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        let cropY = Int(Double(height) * 0.60)
        let cropHeight = height - cropY
        guard cropHeight > 0 else { return nil }
        let cropRect = CGRect(x: 0, y: cropY, width: width, height: cropHeight)
        let cropped = image.cropping(to: cropRect) ?? image
        let bitmap = NSBitmapImageRep(cgImage: cropped)
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.62])
    }

    private func recognizeBatch(
        _ samples: [FrameSample],
        apiKey: String
    ) async throws -> [RecognizedFrameText] {
        var userContent: [[String: Any]] = [
            [
                "type": "text",
                "text": """
                请逐帧读取画面底部字幕。只识别对白字幕，不要读取水印、片名、片尾、界面字、招牌或背景文字。
                看不清就返回空字符串，不要猜。保留原语言与换行。
                每张图前的编号就是 id。只返回 JSON：{"frames":[{"id":编号,"text":"字幕文字","confidence":0到1}]}。
                """,
            ],
        ]

        for sample in samples {
            userContent.append([
                "type": "text",
                "text": "id \(sample.id)，时间 \(formatTime(sample.time))",
            ])
            userContent.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(sample.imageData.base64EncodedString())",
                    "detail": "low",
                ],
            ])
        }

        let body: [String: Any] = [
            "model": model,
            "response_format": ["type": "json_object"],
            "messages": [
                [
                    "role": "system",
                    "content": "你是专业影视字幕识别助手，只按画面可见内容转写字幕，不解释、不补写、不推测。",
                ],
                [
                    "role": "user",
                    "content": userContent,
                ],
            ],
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await execute(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudSubtitleError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw CloudSubtitleError.httpStatus(httpResponse.statusCode)
        }
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = root["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw CloudSubtitleError.invalidResponse
        }
        return try parseFrameTexts(content)
    }

    private func recognizeBatchWithRetry(
        _ samples: [FrameSample],
        apiKey: String,
        processedCount: Int,
        totalCount: Int,
        progress: ProgressReporter?
    ) async throws -> [RecognizedFrameText] {
        let retryDelays: [UInt64] = [20, 45, 90, 150]
        var attempt = 0

        while true {
            do {
                return try await recognizeBatch(samples, apiKey: apiKey)
            } catch {
                if shouldSplitBatch(error), samples.count > 1 {
                    progress?(
                        CloudSubtitleProgress(
                            processed: processedCount,
                            total: totalCount,
                            message: "OpenAI 限制较低，正在改为单张慢速提取…"
                        )
                    )
                    var results: [RecognizedFrameText] = []
                    for sample in samples {
                        let partial = try await recognizeBatchWithRetry(
                            [sample],
                            apiKey: apiKey,
                            processedCount: processedCount,
                            totalCount: totalCount,
                            progress: progress
                        )
                        results.append(contentsOf: partial)
                        if requestDelayNanoseconds > 0 {
                            try? await Task.sleep(nanoseconds: requestDelayNanoseconds)
                        }
                    }
                    return results
                }
                guard shouldRetry(error), attempt < retryDelays.count else {
                    throw error
                }

                let delay = retryDelays[attempt]
                attempt += 1
                progress?(
                    CloudSubtitleProgress(
                        processed: processedCount,
                        total: totalCount,
                        message: "OpenAI 限制中，自动等待 \(delay) 秒后继续…"
                    )
                )
                try await Task.sleep(nanoseconds: delay * 1_000_000_000)
            }
        }
    }

    private func shouldSplitBatch(_ error: Error) -> Bool {
        if let cloudError = error as? CloudSubtitleError {
            switch cloudError {
            case .httpStatus(429):
                return true
            case .httpStatus, .invalidResponse, .invalidRecognition:
                return false
            }
        }
        return false
    }

    private func shouldRetry(_ error: Error) -> Bool {
        if let cloudError = error as? CloudSubtitleError {
            switch cloudError {
            case .httpStatus(429), .httpStatus(500), .httpStatus(503):
                return true
            case .httpStatus, .invalidResponse, .invalidRecognition:
                return false
            }
        }
        if let urlError = error as? URLError {
            return urlError.code == .timedOut
                || urlError.code == .networkConnectionLost
                || urlError.code == .cannotConnectToHost
        }
        return false
    }

    private func parseFrameTexts(_ content: String) throws -> [RecognizedFrameText] {
        let cleaned = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: "^```(?:json)?\\s*|\\s*```$",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        guard
            let data = cleaned.data(using: .utf8),
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = root["frames"] as? [[String: Any]]
        else {
            throw CloudSubtitleError.invalidRecognition
        }

        return items.compactMap { item in
            let id = item["id"] as? Int ?? (item["id"] as? NSNumber)?.intValue
            let text = cleanText(item["text"] as? String ?? "")
            let confidence = item["confidence"] as? Double
                ?? (item["confidence"] as? NSNumber)?.doubleValue
                ?? 0.7
            guard let id else { return nil }
            return RecognizedFrameText(
                id: id,
                text: text,
                confidence: max(0, min(1, confidence))
            )
        }
    }

    private func mergeRecognizedFrames(
        _ frames: [RecognizedFrameText],
        frameTimes: [Int: Double],
        duration: Double
    ) -> [CloudSubtitleCue] {
        let validFrames = frames
            .filter { !$0.text.isEmpty }
            .sorted {
                (frameTimes[$0.id] ?? 0) < (frameTimes[$1.id] ?? 0)
            }
        var cues: [MutableCue] = []
        for frame in validFrames {
            guard let time = frameTimes[frame.id] else { continue }
            let start = max(0, time - sampleInterval * 0.58)
            let end = min(duration, time + sampleInterval * 0.58)
            let normalized = normalizedText(frame.text)
            if
                var last = cues.last,
                normalizedText(last.text) == normalized,
                start - last.end <= sampleInterval * 1.65
            {
                last.end = max(last.end, end)
                last.confidenceTotal += frame.confidence
                last.count += 1
                cues[cues.count - 1] = last
            } else {
                cues.append(
                    MutableCue(
                        start: start,
                        end: max(start + 0.4, end),
                        text: frame.text,
                        confidenceTotal: frame.confidence,
                        count: 1
                    )
                )
            }
        }
        return cues.map(\.cue)
    }

    private func cleanText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedText(_ value: String) -> String {
        cleanText(value)
            .lowercased()
            .filter { !$0.isWhitespace && !$0.isPunctuation }
            .map(String.init)
            .joined()
    }

    private func formatTime(_ totalSeconds: Double) -> String {
        let safeSeconds = max(0, totalSeconds)
        let hours = Int(safeSeconds / 3600)
        let minutes = Int((safeSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(safeSeconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func userMessage(for error: Error) -> String {
        if let cloudError = error as? CloudSubtitleError {
            switch cloudError {
            case .httpStatus(401):
                return "OpenAI 密钥无效，请更换后重试"
            case .httpStatus(402):
                return "OpenAI 账户余额不足，请充值后重试"
            case .httpStatus(429):
                return "OpenAI 限制仍未解除，请稍后再试；软件已自动等待并重试过"
            case .httpStatus(500), .httpStatus(503):
                return "OpenAI 云端字幕提取服务暂时繁忙，请稍后重试"
            case .httpStatus:
                return "云端字幕提取没有完成，请稍后重试"
            case .invalidResponse, .invalidRecognition:
                return "云端返回结果格式异常，请重新提取"
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "网络连接中断，云端字幕提取没有完成"
            case .timedOut:
                return "云端字幕提取等待超时，可以稍后重试"
            default:
                return "网络请求失败，云端字幕提取没有完成"
            }
        }
        return "云端字幕提取没有完成，请稍后重试"
    }

    private enum CloudSubtitleError: Error {
        case httpStatus(Int)
        case invalidResponse
        case invalidRecognition
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var result: [[Element]] = []
        var index = 0
        while index < count {
            let end = Swift.min(index + size, count)
            result.append(Array(self[index..<end]))
            index = end
        }
        return result
    }
}
